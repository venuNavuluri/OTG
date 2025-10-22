public class InstallationTriggerHandler {

    public static Boolean byPassSOcreation = FALSE;

    public static void beforeInsert(List<Installation__c> instList)
    {
        try
        {
            String currentUserAlias = [SELECT Alias FROM User WHERE Id = :UserInfo.getUserId()].Alias;

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
            String currentUserAlias = [SELECT Alias FROM User WHERE Id = :UserInfo.getUserId()].Alias;
    
            List<Id> instIdList = new List<Id>();
            Map<Id, Date> terminationDates = new Map<Id, Date>();
            List<Installation__c> activeInstList = new List<Installation__c>();
            Set<Id> futureTerminatedInstIds = new Set<Id>();
    
            for (Installation__c inst : instList) {
                Installation__c oldInst = oldInstMap.get(inst.Id);
    
                if (currentUserAlias != 'duser') {
                    if (inst.Installation_Order_Status__c == 'Terminated' && oldInst.Installation_Order_Status__c != 'Terminated') {
                        instIdList.add(inst.Id);
                        terminationDates.put(inst.Id, inst.Termination_End_Date__c); // Assuming this field exists
                        if (oldInst.Installation_Order_Status__c == 'Future Terminated') {
                            futureTerminatedInstIds.add(inst.Id);
                        }
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
    
            if (!futureTerminatedInstIds.isEmpty()) {
                List<Installation__c> futureTerminatedInsts = [
                    SELECT Id, Contract__c, Contract__r.EndDate, Package__c, Termination_End_Date__c
                    FROM Installation__c
                    WHERE Id IN :futureTerminatedInstIds
                ];
                for (Installation__c inst : futureTerminatedInsts) {
                    if (inst.Contract__c != null &&
                        inst.Package__c != null &&
                        inst.Termination_End_Date__c != null &&
                        inst.Contract__r != null &&
                        inst.Contract__r.EndDate != inst.Termination_End_Date__c) {
                        CreateInstallationsController.modifyContract(
                            inst.Id,
                            inst.Termination_End_Date__c,
                            inst.Contract__c,
                            inst.Package__c,
                            true
                        );
                    }
                }
            }
    
        } catch (Exception ex) {
            Logger.error('afterUpdate - Exception: ', ex);
            Logger.savelog();
        }
    }

    public static void handleTerminatedInstallations(List<Id> instIdList, Date terminationDate) {
        try {
            Logger.info('Handling Terminated Installations for: ' + instIdList + ' with Termination Date: ' + terminationDate);
    
            List<Sales_Order__c> soList = [
                SELECT Id, Status__c, Start_Date__c, End_Date__c, Installation__c, Contract__c, Invoice_Account__c, CurrencyIsoCode 
                FROM Sales_Order__c 
                WHERE Installation__c IN :instIdList
            ];
    
            if (soList.isEmpty()) {
                Logger.info('No Sales Orders found for termination.');
                return;
            }
    
            List<Sales_Order__c> soListToUpdate = new List<Sales_Order__c>();
            List<Sales_Order__c> newCreditSalesOrders = new List<Sales_Order__c>();
            Map<Id, Id> oldToNewSalesOrderMap = new Map<Id, Id>();
    
            for (Sales_Order__c so : soList) {
                if (so.Status__c == 'Unbilled') {
                    Logger.info('Cancelling Unbilled SO: ' + so.Id);
                    so.Status__c = 'Cancelled';
                    soListToUpdate.add(so);
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
                            Status__c = 'Unbilled',
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
    
            Logger.info('Final Credit Note Mapping: ' + oldToNewSalesOrderMap);
            Logger.saveLog();
    
            createSalesOrderItems(oldToNewSalesOrderMap, terminationDate);
    
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
}