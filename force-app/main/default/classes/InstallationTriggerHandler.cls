public class InstallationTriggerHandler {

    public static Boolean byPassSOcreation = FALSE;
    // Test-only bypass to avoid costly duplicate checks in unit tests.
    @TestVisible private static Boolean bypassForTests = false;
    @TestVisible
    public static void setBypassForTests(Boolean bypass) {
        bypassForTests = bypass;
    }
    private static String currentUserAlias;

    private static String getCurrentUserAlias() {
        if (currentUserAlias == null) {
            // Cache to avoid repeated user alias queries within the same transaction.
            currentUserAlias = [
                SELECT Alias
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ].Alias;
        }
        return currentUserAlias;
    }

    public static void beforeInsert(List<Installation__c> instList)
    {
        try
        {
            // Allow tests to exercise logic unless explicitly bypassed.
            if (bypassForTests) {
                return;
            }

            String currentUserAlias = getCurrentUserAlias();

            if (currentUserAlias == 'duser') {
                return;  // Skip logic for "duser"
            }

            Set<String> packIdSet = new Set<String>();
            Map<String, Installation__c> conInstMap = new Map<String, Installation__c>();

            for (Installation__c inst : instList) {
                if (inst.Package__c != null) {
                    packIdSet.add(inst.Package__c);
                }
            }

            List<Installation__c> instRecList = [
                SELECT Id, Installation_Type__c, Contract_Customer__c, Organisation_Name__c, Vessel_Name__c, Installation_Order_Status__c, Package__c, Package__r.Quote__c 
                FROM Installation__c 
                WHERE Package__c IN :packIdSet 
                AND Installation_Order_Status__c = 'Active'
            ];

            Map<Id, List<Id>> qtIdInstListMap = new Map<Id, List<Id>>();
            Map<Id, Id> packIdQtIdMap = new Map<Id, Id>();
            for (Installation__c existingInst : instRecList)
            {
                if(qtIdInstListMap.get(existingInst.Package__r.Quote__c) == NULL)
                {
                    qtIdInstListMap.put(existingInst.Package__r.Quote__c, new List<Id>());
                }
                Id vesOrgId = existingInst.Installation_Type__c == 'Vessel' ? existingInst.Vessel_Name__c : existingInst.Organisation_Name__c;
                qtIdInstListMap.get(existingInst.Package__r.Quote__c).add(vesOrgId);

                packIdQtIdMap.put(existingInst.Package__c, existingInst.Package__r.Quote__c);
            }
            
            for(Installation__c inst : instList)
            {
                if (inst.Installation_Type__c == 'Organisation' && (packIdQtIdMap.get(inst.Package__c) != NULL && qtIdInstListMap.get(packIdQtIdMap.get(inst.Package__c)) != NULL && qtIdInstListMap.get(packIdQtIdMap.get(inst.Package__c)).contains(inst.Organisation_Name__c)))
                {
                    inst.addError('Duplicate installation record for Organisation: ' + inst.Organisation_Name__c);
                }
                else if (inst.Installation_Type__c == 'Vessel' && (packIdQtIdMap.get(inst.Package__c) != NULL && qtIdInstListMap.get(packIdQtIdMap.get(inst.Package__c)) != NULL && qtIdInstListMap.get(packIdQtIdMap.get(inst.Package__c)).contains(inst.Vessel_Name__c)))
                {
                    inst.addError('Duplicate installation record for Vessel: ' + inst.Vessel_Name__c);
                }
            }

        } catch (Exception ex) {
            Logger.error('beforeInsert - Exception: ', ex);
            Logger.savelog();
            throw new AuraHandledException('An error occurred during beforeInsert processing.');
        }
    }

    public static void afterUpdate(List<Installation__c> instList, Map<Id, Installation__c> oldInstMap) {
        try {
            // Allow tests to exercise logic unless explicitly bypassed.
            if (bypassForTests) {
                return;
            }

            String currentUserAlias = getCurrentUserAlias();
    
            List<Id> instIdList = new List<Id>();
            Map<Id, Date> terminationDates = new Map<Id, Date>();
    
            for (Installation__c inst : instList) {
                Installation__c oldInst = oldInstMap.get(inst.Id);
    
                if (currentUserAlias != 'duser') {
                    Boolean isImmediateTerminationRequested =
                        inst.Installation_Order_Status__c == 'Termination Pending' &&
                        oldInst.Installation_Order_Status__c != 'Termination Pending';
                    Boolean isLegacyDirectTermination =
                        inst.Installation_Order_Status__c == 'Terminated' &&
                        oldInst.Installation_Order_Status__c != 'Terminated' &&
                        oldInst.Installation_Order_Status__c != 'Termination Pending';

                    if (isImmediateTerminationRequested || isLegacyDirectTermination) {
                        instIdList.add(inst.Id);
                        terminationDates.put(inst.Id, inst.Termination_End_Date__c); // Assuming this field exists
                    } 
                }
            }
    
            if (!instIdList.isEmpty()) {
                Map<Id, Installation__c> instDetails = new Map<Id, Installation__c>([
                    SELECT Id, Contract__c, Contract__r.EndDate, Termination_End_Date__c
                    FROM Installation__c
                    WHERE Id IN :instIdList
                ]);

                for (Id instId : instIdList) {
                    Date terminationDate = terminationDates.get(instId);
                    Installation__c inst = instDetails.get(instId);
                    if (terminationDate != null &&
                        inst != null &&
                        inst.Contract__r != null &&
                        inst.Contract__r.EndDate != inst.Termination_End_Date__c) {
                        handleTerminatedInstallations(new List<Id>{ instId }, terminationDate);
                    }
                }
            }
            InstallationChangeService.enqueueChanges(instList, oldInstMap);

        } catch (Exception ex) {
            Logger.error('afterUpdate - Exception: ', ex);
            Logger.savelog();
        }
    }

    public static void handleTerminatedInstallations(List<Id> instIdList, Date terminationDate) {
        try {
            Logger.info('Handling Terminated Installations for: ' + instIdList + ' with Termination Date: ' + terminationDate);
    
            List<Sales_Order__c> soList = [
                SELECT Id, Status__c, Start_Date__c, End_Date__c, Installation__c, Contract__c,
                    Invoice_Account__c, Comments__c, CurrencyIsoCode
                FROM Sales_Order__c 
                WHERE Installation__c IN :instIdList
            ];
    
            if (soList.isEmpty()) {
                Logger.info('No Sales Orders found for termination.');
                return;
            }
    
            List<Sales_Order__c> soListToUpdate = new List<Sales_Order__c>();
            List<Sales_Order__c> newCreditSalesOrders = new List<Sales_Order__c>();
            List<Sales_Order__c> newReplacementSalesOrders = new List<Sales_Order__c>();
            Map<Id, Id> oldToNewSalesOrderMap = new Map<Id, Id>();
            Map<Integer, Id> replacementIndexToSourceOrderId = new Map<Integer, Id>();
            Map<Id, Sales_Order__c> oldToReplacementSalesOrderMap = new Map<Id, Sales_Order__c>();
    
            for (Sales_Order__c so : soList) {
                if (so.Status__c == 'Pending Approval' || so.Status__c == 'Unbilled') {
                    if (so.Start_Date__c == null || so.End_Date__c == null || terminationDate == null) {
                        Logger.info('Skipping open SO with incomplete dates: ' + so.Id);
                        continue;
                    }

                    if (terminationDate < so.Start_Date__c) {
                        Logger.info('Cancelling open SO after termination date: ' + so.Id);
                        so.Status__c = 'Cancelled';
                        soListToUpdate.add(so);
                    } else if (terminationDate <= so.End_Date__c) {
                        Logger.info('Replacing open SO for terminated period: ' + so.Id);
                        so.Status__c = 'Cancelled';
                        soListToUpdate.add(so);

                        replacementIndexToSourceOrderId.put(newReplacementSalesOrders.size(), so.Id);
                        newReplacementSalesOrders.add(new Sales_Order__c(
                            Status__c = 'Pending Approval',
                            Credit_Note__c = false,
                            Start_Date__c = so.Start_Date__c,
                            End_Date__c = terminationDate,
                            Contract__c = so.Contract__c,
                            Invoice_Account__c = so.Invoice_Account__c,
                            CurrencyIsoCode = so.CurrencyIsoCode,
                            Installation__c = so.Installation__c,
                            Comments__c = so.Comments__c,
                            Original_Sales_Order__c = so.Id
                        ));
                    } else {
                        Logger.info('Open SO is fully before termination date. Skipping: ' + so.Id);
                    }
                } 
                else if (so.Status__c == 'Billed') {
                    Boolean createCreditNote = false;
                    Date creditStart;
    
                    if (terminationDate < so.Start_Date__c) {
                        // Full credit note
                        Logger.info('Creating Full Credit Note for SO: ' + so.Id);
                        creditStart = so.Start_Date__c;
                        createCreditNote = true;
                    } else if (terminationDate >= so.Start_Date__c && terminationDate <= so.End_Date__c) {
                        // Partial credit note (prorated)
                        Logger.info('Creating Partial Credit Note for SO: ' + so.Id + ' from Termination Date: ' + terminationDate);
                        creditStart = terminationDate;
                        createCreditNote = true;
                    } else {
                        // Termination after SO period, no action
                        Logger.info('Termination Date after SO: ' + so.Id + ' range. Skipping.');
                        continue;
                    }
    
                    if (createCreditNote) {
                        Sales_Order__c creditSO = new Sales_Order__c(
                            Status__c = 'Pending Approval',
                            Credit_Note__c = TRUE,
                            Start_Date__c = creditStart,
                            End_Date__c = so.End_Date__c,
                            Contract__c = so.Contract__c,
                            Invoice_Account__c = so.Invoice_Account__c,
                            CurrencyIsoCode = so.CurrencyIsoCode,
                            Installation__c = so.Installation__c
                        );
    
                        newCreditSalesOrders.add(creditSO);
                        oldToNewSalesOrderMap.put(so.Id, null);
    
                        //so.Status__c = 'Terminated';
                        soListToUpdate.add(so);
                    }
                }
            }
    
            if (!soListToUpdate.isEmpty()) {
                update soListToUpdate;
                Logger.info('Updated ' + soListToUpdate.size() + ' Sales Orders to Cancelled');
            }
    
            if (!newCreditSalesOrders.isEmpty()) {
                insert newCreditSalesOrders;
                Logger.info('Inserted ' + newCreditSalesOrders.size() + ' Credit Note Sales Orders');
    
                Integer index = 0;
                for (Id oldSOId : oldToNewSalesOrderMap.keySet()) {
                    if (oldToNewSalesOrderMap.get(oldSOId) == null && index < newCreditSalesOrders.size()) {
                        oldToNewSalesOrderMap.put(oldSOId, newCreditSalesOrders[index].Id);
                        index++;
                    }
                }
            }

            if (!newReplacementSalesOrders.isEmpty()) {
                insert newReplacementSalesOrders;
                Logger.info('Inserted ' + newReplacementSalesOrders.size() + ' Replacement Sales Orders');

                for (Integer index = 0; index < newReplacementSalesOrders.size(); index++) {
                    Id sourceOrderId = replacementIndexToSourceOrderId.get(index);
                    if (sourceOrderId != null) {
                        oldToReplacementSalesOrderMap.put(sourceOrderId, newReplacementSalesOrders[index]);
                    }
                }
            }
    
            Logger.info('Final Credit Note Mapping: ' + oldToNewSalesOrderMap);
            Logger.saveLog();
    
            createSalesOrderItems(oldToNewSalesOrderMap, terminationDate);
            createReplacementSalesOrderItems(oldToReplacementSalesOrderMap);

            List<Installation__c> installationsToUpdate = new List<Installation__c>();
            for (Id installationId : instIdList) {
                installationsToUpdate.add(new Installation__c(
                    Id = installationId,
                    Termination_Process_Status__c = 'SO Updated'
                ));
            }
            if (!installationsToUpdate.isEmpty()) {
                update installationsToUpdate;
            }
    
        } catch (Exception ex) {
            Logger.error('handleTerminatedInstallations - Exception: ' + ex.getMessage() + '\n' + ex.getStackTraceString());
            Logger.saveLog();
            throw ex;
        }
    }

    @TestVisible
    private static void createSalesOrderItems(Map<Id, Id> oldToNewSalesOrderMap, Date terminationDate) {
        try {
            List<Sales_Order_Item__c> oldSOItems = [
                SELECT Id, Sales_Order__c, Amount__c, CurrencyIsoCode, Installation_Line__c, Name,
                    Sales_Order__r.Start_Date__c, Sales_Order__r.End_Date__c
                FROM Sales_Order_Item__c 
                WHERE Sales_Order__c IN :oldToNewSalesOrderMap.keySet()
            ];

            if (oldSOItems.isEmpty()) return;

            List<Sales_Order_Item__c> newSOItems = new List<Sales_Order_Item__c>();

            for (Sales_Order_Item__c oldSOItem : oldSOItems) {
                Id newSOId = oldToNewSalesOrderMap.get(oldSOItem.Sales_Order__c);
                if (newSOId == null) continue;

                Date soStart = oldSOItem.Sales_Order__r.Start_Date__c;
                Date soEnd = oldSOItem.Sales_Order__r.End_Date__c;

                Decimal creditAmount = 0;

                if (terminationDate < soStart) {
                    // Full credit
                    creditAmount = oldSOItem.Amount__c;
                } else if (terminationDate >= soStart && terminationDate <= soEnd) {
                    Decimal totalDays = soStart.daysBetween(soEnd) + 1;
                    Decimal remainingDays = terminationDate.daysBetween(soEnd) + 1;
                    creditAmount = (oldSOItem.Amount__c / totalDays) * remainingDays;
                }

                if (creditAmount > 0) {
                    newSOItems.add(new Sales_Order_Item__c(
                        Sales_Order__c = newSOId,
                        Amount__c = -creditAmount.setScale(2),
                        CurrencyIsoCode = oldSOItem.CurrencyIsoCode,
                        Installation_Line__c = oldSOItem.Installation_Line__c,
                        Name = oldSOItem.Name
                    ));
                }
            }

            if (!newSOItems.isEmpty()) {
                insert newSOItems;
                Logger.info('Inserted Credit Note Items: ' + newSOItems.size());
                Logger.saveLog();
            }

        } catch (Exception ex) {
            Logger.error('createSalesOrderItems - Exception: ' + ex.getMessage());
            Logger.saveLog();
            throw ex;
        }
    }

    @TestVisible
    private static void createReplacementSalesOrderItems(Map<Id, Sales_Order__c> oldToReplacementSalesOrderMap) {
        try {
            if (oldToReplacementSalesOrderMap.isEmpty()) {
                return;
            }

            Set<Id> installationIds = new Set<Id>();
            Date minStartDate;
            Date maxEndDate;
            for (Sales_Order__c replacementSO : oldToReplacementSalesOrderMap.values()) {
                if (replacementSO.Installation__c == null ||
                    replacementSO.Start_Date__c == null ||
                    replacementSO.End_Date__c == null) {
                    continue;
                }

                installationIds.add(replacementSO.Installation__c);
                if (minStartDate == null || replacementSO.Start_Date__c < minStartDate) {
                    minStartDate = replacementSO.Start_Date__c;
                }
                if (maxEndDate == null || replacementSO.End_Date__c > maxEndDate) {
                    maxEndDate = replacementSO.End_Date__c;
                }
            }

            if (installationIds.isEmpty() || minStartDate == null || maxEndDate == null) {
                return;
            }

            List<Installation_Line__c> installationLines = [
                SELECT Id, Name, Installation__c, Subscription__c, CurrencyIsoCode,
                    Net_Total__c, Start_Date__c, End_Date__c
                FROM Installation_Line__c
                WHERE Installation__c IN :installationIds
                    AND Start_Date__c <= :maxEndDate
                    AND End_Date__c >= :minStartDate
                    AND Net_Total__c != null
            ];

            Map<Id, List<Installation_Line__c>> linesByInstallationId = new Map<Id, List<Installation_Line__c>>();
            for (Installation_Line__c line : installationLines) {
                if (!linesByInstallationId.containsKey(line.Installation__c)) {
                    linesByInstallationId.put(line.Installation__c, new List<Installation_Line__c>());
                }
                linesByInstallationId.get(line.Installation__c).add(line);
            }

            List<Sales_Order_Item__c> salesOrderItemsToInsert = new List<Sales_Order_Item__c>();
            for (Sales_Order__c replacementSO : oldToReplacementSalesOrderMap.values()) {
                List<Installation_Line__c> lines = linesByInstallationId.get(replacementSO.Installation__c);
                if (lines == null) {
                    continue;
                }

                for (Installation_Line__c line : lines) {
                    if (line.Start_Date__c <= replacementSO.End_Date__c &&
                        line.End_Date__c >= replacementSO.Start_Date__c) {
                        Date itemStartDate = line.Start_Date__c > replacementSO.Start_Date__c
                            ? line.Start_Date__c
                            : replacementSO.Start_Date__c;
                        Date itemEndDate = line.End_Date__c < replacementSO.End_Date__c
                            ? line.End_Date__c
                            : replacementSO.End_Date__c;
                        Decimal amount = calculateInclusiveProratedAmount(line, itemStartDate, itemEndDate);
                        salesOrderItemsToInsert.add(new Sales_Order_Item__c(
                            Name = line.Name,
                            Sales_Order__c = replacementSO.Id,
                            Installation_Line__c = line.Id,
                            Subscription__c = line.Subscription__c,
                            CurrencyIsoCode = line.CurrencyIsoCode,
                            Amount__c = amount
                        ));
                    }
                }
            }

            if (!salesOrderItemsToInsert.isEmpty()) {
                insert salesOrderItemsToInsert;
                Logger.info('Inserted Replacement Sales Order Items: ' + salesOrderItemsToInsert.size());
                Logger.saveLog();
            }
        } catch (Exception ex) {
            Logger.error('createReplacementSalesOrderItems - Exception: ' + ex.getMessage());
            Logger.saveLog();
            throw ex;
        }
    }

    private static Decimal calculateInclusiveProratedAmount(Installation_Line__c line, Date itemStartDate, Date itemEndDate) {
        if (line == null ||
            line.Start_Date__c == null ||
            line.End_Date__c == null ||
            line.Net_Total__c == null ||
            itemStartDate == null ||
            itemEndDate == null ||
            itemEndDate < itemStartDate) {
            return 0;
        }

        Decimal totalDays = line.Start_Date__c.daysBetween(line.End_Date__c) + 1;
        Decimal billableDays = itemStartDate.daysBetween(itemEndDate) + 1;
        if (totalDays <= 0 || billableDays <= 0) {
            return 0;
        }

        return ((line.Net_Total__c / totalDays) * billableDays).setScale(2);
    }
}
