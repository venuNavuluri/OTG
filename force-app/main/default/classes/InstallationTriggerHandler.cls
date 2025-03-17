public class InstallationTriggerHandler {

    public static Boolean byPassSOcreation = FALSE;

    /*public static void beforeInsert(List<Installation__c> instList) {
        try {
            String currentUserAlias = [SELECT Alias FROM User WHERE Id = :UserInfo.getUserId()].Alias;

            if (currentUserAlias == 'duser') {
                return;  // Skip logic for "duser"
            }

            Set<String> contractCustomerSet = new Set<String>();
            Map<String, Installation__c> contVessStatusMap = new Map<String, Installation__c>();
            Map<String, Installation__c> contOrgStatusMap = new Map<String, Installation__c>();
            Map<String, Installation__c> conInstMap = new Map<String, Installation__c>();

            for (Installation__c inst : instList) {
                if (inst.Contract_Customer__c != null) {
                    contractCustomerSet.add(inst.Contract_Customer__c);
                }

                if (inst.Vessel_Name__c != null) {
                    contVessStatusMap.put(inst.Contract_Customer__c + '-' + inst.Vessel_Name__c, inst);
                } else if (inst.Organisation_Name__c != null) {
                    contOrgStatusMap.put(inst.Contract_Customer__c + '-' + inst.Organisation_Name__c, inst);
                }

                if (inst.Contract__c != null) {
                    conInstMap.put(inst.Contract__c, inst);
                }
            }

            List<Installation__c> instRecList = [
                SELECT Id, Contract_Customer__c, Organisation_Name__c, Vessel_Name__c, Installation_Order_Status__c 
                FROM Installation__c 
                WHERE Contract_Customer__c IN :contractCustomerSet 
                AND Installation_Order_Status__c = 'Active'
            ];

            for (Installation__c existingInst : instRecList) {
                if (contOrgStatusMap.containsKey(existingInst.Contract_Customer__c + '-' + existingInst.Organisation_Name__c)) {
                    contOrgStatusMap.get(existingInst.Contract_Customer__c + '-' + existingInst.Organisation_Name__c)
                        .addError('Duplicate installation record for Organisation: ' + existingInst.Organisation_Name__c);
                } else if (contVessStatusMap.containsKey(existingInst.Contract_Customer__c + '-' + existingInst.Vessel_Name__c)) {
                    contVessStatusMap.get(existingInst.Contract_Customer__c + '-' + existingInst.Vessel_Name__c)
                        .addError('Duplicate installation record for Vessel: ' + existingInst.Vessel_Name__c);
                }
            }

            if (!conInstMap.isEmpty()) {
                List<Contract> conList = [
                    SELECT Id, StartDate, EndDate 
                    FROM Contract 
                    WHERE Id IN :conInstMap.keySet() 
                    AND StartDate != null 
                    AND EndDate != null
                ];

                for (Contract con : conList) {
                    Installation__c inst = conInstMap.get(con.Id);
                    inst.Installation_Start_Date__c = con.StartDate;
                    inst.Installation_End_Date__c = con.EndDate;
                }
            }

        } catch (Exception ex) {
            Logger.error('beforeInsert - Exception: ', ex);
            Logger.savelog();
            throw new AuraHandledException('An error occurred during beforeInsert processing.');
        }
    }*/

    public static void beforeInsert(List<Installation__c> instList)
    {
        try
        {
            String currentUserAlias = [SELECT Alias FROM User WHERE Id = :UserInfo.getUserId()].Alias;

            if (currentUserAlias == 'duser') {
                return;  // Skip logic for "duser"
            }

            Set<String> packIdSet = new Set<String>();
            //Map<String, Installation__c> contVessStatusMap = new Map<String, Installation__c>();
            //Map<String, Installation__c> contOrgStatusMap = new Map<String, Installation__c>();
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

            if (!conInstMap.isEmpty()) {
                List<Contract> conList = [
                    SELECT Id, StartDate, EndDate 
                    FROM Contract 
                    WHERE Id IN :conInstMap.keySet() 
                    AND StartDate != null 
                    AND EndDate != null
                ];

                for (Contract con : conList) {
                    Installation__c inst = conInstMap.get(con.Id);
                    inst.Installation_Start_Date__c = con.StartDate;
                    inst.Installation_End_Date__c = con.EndDate;
                }
            }

        } catch (Exception ex) {
            System.debug('Exception ex --> ' + ex);
            System.debug('Exception line --> ' + ex.getLineNumber());
            System.debug('Ex --> ' + ex.getMessage());
            Logger.error('beforeInsert - Exception: ', ex);
            Logger.savelog();
            throw new AuraHandledException('An error occurred during beforeInsert processing.');
        }
    }

    public static void afterUpdate(List<Installation__c> instList, Map<Id, Installation__c> oldInstMap) {
        try {
            String currentUserAlias = [SELECT Alias FROM User WHERE Id = :UserInfo.getUserId()].Alias;

            List<Id> instIdList = new List<Id>();
            List<Installation__c> activeInstList = new List<Installation__c>();

            for (Installation__c inst : instList) {
                if (currentUserAlias != 'duser') {
                    if (inst.Auto_Termination__c && (inst.Installation_Order_Status__c == 'Terminated' && oldInstMap.get(inst.Id).Installation_Order_Status__c != 'Terminated')) {
                        instIdList.add(inst.Id);
                    } else if (inst.Installation_Order_Status__c == 'Active' && oldInstMap.get(inst.Id).Installation_Order_Status__c != 'Active') {
                        if(inst.Contract__r.SBQQ__Quote__r.SBQQ__Type__c == 'Renewal'){
                          activeInstList.add(inst);  
                        }
                    }
                }
            }

            if (!instIdList.isEmpty()) {
                handleTerminatedInstallations(instIdList);
            }

            if (!activeInstList.isEmpty()) {
                CreateSalesOrderService.createSORecords(activeInstList);
            }

        } catch (Exception ex) {
            Logger.error('afterUpdate - Exception: ', ex);
            Logger.savelog();
            //throw new AuraHandledException('An error occurred during afterUpdate processing.');
        }
    }

    private static void handleTerminatedInstallations(List<Id> instIdList) {
        try {
            List<Sales_Order__c> soList = [
                SELECT Id, Status__c, Start_Date__c, End_Date__c, Installation__c, Contract__c, Invoice_Account__c, CurrencyIsoCode 
                FROM Sales_Order__c 
                WHERE Installation__c IN :instIdList
            ];

            if (soList.isEmpty()) {
                return;
            }

            List<Sales_Order__c> soListToUpdate = new List<Sales_Order__c>();
            List<Sales_Order__c> newCreditSalesOrders = new List<Sales_Order__c>();
            Map<Id, Id> oldToNewSalesOrderMap = new Map<Id, Id>();

            for (Sales_Order__c so : soList) {
                if (so.Status__c == 'Unbilled') {
                    so.Status__c = 'Cancelled';
                    soListToUpdate.add(so);
                } else if (so.Status__c == 'Billed' && so.End_Date__c >= Date.today() && so.Start_Date__c <= Date.today()) {
                    Sales_Order__c newCreditSO = new Sales_Order__c(
                        Status__c = 'Unbilled',
                        Credit_Note__c = TRUE,
                        Start_Date__c = Date.today(),
                        End_Date__c = so.End_Date__c,
                        Contract__c = so.Contract__c,
                        Invoice_Account__c = so.Invoice_Account__c,
                        CurrencyIsoCode = so.CurrencyIsoCode,
                        Installation__c = so.Installation__c
                    );
                    newCreditSalesOrders.add(newCreditSO);

                    so.Status__c = 'Cancelled';
                    soListToUpdate.add(so);
                    oldToNewSalesOrderMap.put(so.Id, null);  // Temporary mapping for new IDs
                }
            }

            if (!soListToUpdate.isEmpty()) {
                update soListToUpdate;
            }

            if (!newCreditSalesOrders.isEmpty()) {
                insert newCreditSalesOrders;

                for (Sales_Order__c newSO : newCreditSalesOrders) {
                    for (Id oldSOId : oldToNewSalesOrderMap.keySet()) {
                        if (oldToNewSalesOrderMap.get(oldSOId) == null) {
                            oldToNewSalesOrderMap.put(oldSOId, newSO.Id);
                        }
                    }
                }
            }
            
            System.debug('oldToNewSalesOrderMap --> ' + oldToNewSalesOrderMap);

            createSalesOrderItems(oldToNewSalesOrderMap);

        } catch (Exception ex) {
            Logger.error('handleTerminatedInstallations - Exception: ', ex);
            Logger.savelog();
            throw ex;
        }
    }

    @Testvisible
    private static void createSalesOrderItems(Map<Id, Id> oldToNewSalesOrderMap) {
        try {
            List<Sales_Order_Item__c> oldSOItems = [
                SELECT Id, Sales_Order__c, Amount__c, CurrencyIsoCode, Installation_Line__c, Name,
                       Sales_Order__r.Start_Date__c, Sales_Order__r.End_Date__c
                FROM Sales_Order_Item__c 
                WHERE Sales_Order__c IN :oldToNewSalesOrderMap.keySet()
            ];
            
            System.debug('oldSOItems --> ' + oldSOItems);

            if (oldSOItems.isEmpty()) {
                return;
            }

            List<Sales_Order_Item__c> newSOItems = new List<Sales_Order_Item__c>();

            for (Sales_Order_Item__c oldSOItem : oldSOItems) {
                Id newSOId = oldToNewSalesOrderMap.get(oldSOItem.Sales_Order__c);
                if (newSOId != null) {
                    Decimal totalDays = oldSOItem.Sales_Order__r.Start_Date__c.daysBetween(oldSOItem.Sales_Order__r.End_Date__c);
                    Decimal remainingDays = Date.today().daysBetween(oldSOItem.Sales_Order__r.End_Date__c);
                    Decimal proratedAmount = (oldSOItem.Amount__c / totalDays) * remainingDays;

                    newSOItems.add(new Sales_Order_Item__c(
                        Sales_Order__c = newSOId,
                        Amount__c = proratedAmount.abs() * -1,
                        CurrencyIsoCode = oldSOItem.CurrencyIsoCode,
                        Installation_Line__c = oldSOItem.Installation_Line__c,
                        Name = oldSOItem.Name
                    ));
                }
            }

            if (!newSOItems.isEmpty()) {
                insert newSOItems;
            }

        } catch (Exception ex) {
            Logger.error('createSalesOrderItems - Exception: ', ex);
            Logger.savelog();
            throw ex;
        }
    }
}