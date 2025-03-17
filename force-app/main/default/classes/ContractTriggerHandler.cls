public class ContractTriggerHandler {
    private static Boolean isExecuting = false; // Declare the variable
    
    public static void onBeforeInsert() {
        updatePreviousContract((List<Contract>)Trigger.new);
    }

    public static void onBeforeUpdate() {
         if (!isExecuting) {
            isExecuting = true;
            updatePreviousContract((List<Contract>)Trigger.new);
            updateSubscriptionValue((List<Contract>)Trigger.new, (Map<Id, Contract>)Trigger.oldMap);
            isExecuting = false;
        }
    }

    public static void onAfterInsert() {
        updateContractDetails((Map<Id, Contract>)Trigger.newMap);
        updateNextContract((Map<Id, Contract>)Trigger.newMap);
    }
    
    public static void onAfterUpdate() {
        activateContracts((Map<Id, Contract>)Trigger.newMap, (Map<Id, Contract>)Trigger.oldMap);
    }
    
    /**
     * Activates contracts and processes related installations.
     */
    public static void activateContracts(Map<Id, Contract> newContrMap, Map<Id, Contract> oldContrMap) {
        if (isExecuting) return;  // Prevent recursion
        isExecuting = true;

        try {
            // Bypass logic if current user is 'duser'
            String currentUserAlias = [SELECT Alias FROM User WHERE Id = :UserInfo.getUserId()].Alias;
            if (currentUserAlias == 'duser') return;

            Set<Id> contractIds = newContrMap.keySet();
            List<Id> activeContrList = new List<Id>();

            // Bulk Fetch Contracts to avoid multiple queries inside loop
            Map<Id, Contract> contrMap = new Map<Id, Contract>([
                SELECT Id, SBQQ__Quote__c, SBQQ__Quote__r.SBQQ__Type__c 
                FROM Contract WHERE Id IN :contractIds
            ]);

           // Identify activated contracts
            for (Id contrId : contractIds) {
                Contract newContr = newContrMap.get(contrId);
                Contract oldContr = oldContrMap.get(contrId);
            
                // Ensure oldContr exists to avoid NullPointerException
                if (oldContr != null && newContr.Status == 'Activated' && oldContr.Status != 'Activated') {
                    if (contrMap.containsKey(contrId)) {
                        String quoteType = contrMap.get(contrId).SBQQ__Quote__r.SBQQ__Type__c;
                        if (quoteType == 'Renewal' || quoteType == 'Quote') {
                            activeContrList.add(contrId);
                        }
                    }
                }
            }

            // Fetch Installations related to active contracts
            if (!activeContrList.isEmpty()) {
                List<Installation__c> instList = [
                    SELECT Id, Name, Contract__c, Contract__r.SBQQ__Quote__r.SBQQ__Type__c, 
                    Contract__r.StartDate, Contract__r.EndDate, 
                    Order__c, Order__r.SBQQ__Quote__c, 
                    Quote_Line_Group__r.SBQQ__Quote__c, Order__r.ActivatedDate
                    FROM Installation__c 
                    WHERE Contract__c IN :activeContrList 
                    AND Installation_Order_Status__c != 'Terminated'
                    ORDER BY CreatedDate DESC
                ];
                activate(instList);
            }

            updateNextContract(newContrMap);
            
        } catch (Exception ex) {
            Logger.error(ex.getMessage() + '\n' + ex.getLineNumber() + '\n' + ex.getStackTraceString());
            Logger.saveLog();
        } finally {
            isExecuting = false; // Reset recursion flag
        }
    }

   public static void updatePreviousContract(List<Contract> newContrList) {
    try {
        // Retrieve the current user's alias
        String currentUserAlias = [SELECT Alias FROM User WHERE Id = :UserInfo.getUserId()].Alias;
        
        // Bypass the logic if the current user alias is 'duser'
        if (currentUserAlias == 'duser') {
            return;
        }

        Set<Id> quoteIds = new Set<Id>();
        Set<Id> opportunityIds = new Set<Id>();

        // Step 1: Collect Quote and Opportunity IDs
        for (Contract con : newContrList) {
            if (con.SBQQ__Quote__c != null && con.SBQQ__Opportunity__c != null && con.Previous_Contract__c == null) {
                quoteIds.add(con.SBQQ__Quote__c);
                opportunityIds.add(con.SBQQ__Opportunity__c);
            }
        }

        if (quoteIds.isEmpty() || opportunityIds.isEmpty()) {
            return; // No relevant contracts to update
        }

        // Step 2: Bulk Fetch Quotes
        Map<Id, SBQQ__Quote__c> quoteMap = new Map<Id, SBQQ__Quote__c>(
            [SELECT Id, SBQQ__Type__c, Agreement_Type__c, SBQQ__BillingFrequency__c
             FROM SBQQ__Quote__c WHERE Id IN :quoteIds]
        );

        // Step 3: Bulk Fetch Opportunities
        Map<Id, Opportunity> opportunityMap = new Map<Id, Opportunity>(
            [SELECT Id, Name, SBQQ__RenewedContract__c, Legal_Entity__c, Number_of_Installations__c, Business_Unit__c,
              Customer_Signed_By__c, Contract_Agreement_Signed_Date__c, Company_Signed_By__c, Company_Signed_Date__c, Contact_Name__r.Job_Title__c,Customer_Signed_By__r.Job_Title__c,
                    SBQQ__RenewedContract__r.Subscription_System__c, 
                    SBQQ__RenewedContract__r.Agreement_Type__c,
                    SBQQ__RenewedContract__r.Next_Renewal_Date__c,
                    SBQQ__RenewedContract__r.Renewal_Month__c,
                    SBQQ__RenewedContract__r.ActivatedDate,
                    SBQQ__RenewedContract__r.Agreement_ID__c,
                    SBQQ__RenewedContract__r.Original_Fixed_Term_Start_Date__c,
                    SBQQ__RenewedContract__r.Original_Fixed_Term_End_Date__c,
                    SBQQ__RenewedContract__r.Original_Fixed_Term__c,
                    SBQQ__RenewedContract__r.Subscription_Value__c,
                    SBQQ__PrimaryQuote__c, 
                    SBQQ__PrimaryQuote__r.SBQQ__DeliveryMethod__c,
                    SBQQ__PrimaryQuote__r.SBQQ__StartDate__c, 
                    SBQQ__PrimaryQuote__r.SBQQ__EndDate__c
             FROM Opportunity WHERE Id IN :opportunityIds]
        );

        // Step 4: Modify Trigger.new Directly (No DML Needed in Before Triggers)
        for (Contract con : newContrList) {
            SBQQ__Quote__c quote = quoteMap.get(con.SBQQ__Quote__c);
            Opportunity opp = opportunityMap.get(con.SBQQ__Opportunity__c);

            if (quote != null && opp != null) {
                // Update contract fields directly within before trigger
                con.Legal_Entity__c = opp.Legal_Entity__c;
                con.No_of_Installations__c = opp.Number_of_Installations__c;
                con.Business_Unit__c = opp.Business_Unit__c;
                con.Unit_of_Measure__c = quote.Agreement_Type__c;
                con.Default_Delivery_Method__c = opp.SBQQ__PrimaryQuote__r.SBQQ__DeliveryMethod__c;
                con.Billing_Frequency__c = quote.SBQQ__BillingFrequency__c;
                con.CustomerSignedId = opp.Customer_Signed_By__c; 
                con.CustomerSignedDate = opp.Contract_Agreement_Signed_Date__c; 
                con.CompanySignedId = opp.Company_Signed_By__c;
                con.CompanySignedDate = opp.Company_Signed_Date__c;
                con.CustomerSignedTitle = opp.Customer_Signed_By__r.Job_Title__c;

                // Handle Renewal Contracts
                if (quote.SBQQ__Type__c == 'Renewal') {
                    con.StartDate = opp.SBQQ__PrimaryQuote__r.SBQQ__StartDate__c;
                    con.EndDate = opp.SBQQ__PrimaryQuote__r.SBQQ__EndDate__c;
                    con.Previous_Contract__c = opp.SBQQ__RenewedContract__c;
                    con.Subscription_System__c = opp.SBQQ__RenewedContract__r.Subscription_System__c;
                    con.Agreement_Type__c = opp.SBQQ__RenewedContract__r.Agreement_Type__c;
                    con.Next_Renewal_Date__c = opp.SBQQ__RenewedContract__r.Next_Renewal_Date__c;
                    //con.Renewal_Month__c = opp.SBQQ__RenewedContract__r.Renewal_Month__c;
                    //con.Agreement_ID__c = opp.SBQQ__RenewedContract__r.Agreement_ID__c;
                    con.Original_Fixed_Term_Start_Date__c = opp.SBQQ__RenewedContract__r.Original_Fixed_Term_Start_Date__c;
                    con.Original_Fixed_Term_End_Date__c = opp.SBQQ__RenewedContract__r.Original_Fixed_Term_End_Date__c;
                    con.Original_Fixed_Term__c = opp.SBQQ__RenewedContract__r.Original_Fixed_Term__c;
                    con.Subscription_Value__c = opp.SBQQ__RenewedContract__r.Subscription_Value__c;
                }
            }
        }
    } catch (Exception ex) {
        Logger.error(ex.getMessage() + '\n' + ex.getLineNumber() + '\n' + ex.getStackTraceString());
        Logger.saveLog();
    }
}

    public static void updateNextContract(Map<Id, Contract> newContrMap) {
        try {
            if (newContrMap.isEmpty()) {
                return; // Exit early if there's nothing to process
            }

            List<Contract> contractsToUpdate = new List<Contract>();

            for (Contract contr : newContrMap.values()) {
                if (contr.Previous_Contract__c != null) {
                    contractsToUpdate.add(new Contract(
                        Id = contr.Previous_Contract__c,
                        Next_Contract__c = contr.Id
                    ));
                }
            }

            if (!contractsToUpdate.isEmpty()) {
                update contractsToUpdate;
            }
        } catch (Exception ex) {
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
        }
    }

    public static void updateContractDetails(Map<Id, Contract> contractMap) {
        // Retrieve the current user's alias
        String currentUserAlias = [SELECT Alias FROM User WHERE Id = :UserInfo.getUserId()].Alias;

        // Bypass the logic if the current user alias is 'duser'
        if (currentUserAlias == 'duser') {
            return; // Exit the method
        }

        try {
            if (contractMap.isEmpty()) {
                return; 
            }

            // Step 1: Collect Quote ID to Contract ID mapping
            Map<Id, Id> quoteToContractMap = new Map<Id, Id>();
            for (Contract contract : contractMap.values()) {
                if (contract.SBQQ__Quote__c != null && !contract.Migrated_Contract__c) {
                    quoteToContractMap.put(contract.SBQQ__Quote__c, contract.Id);
                }
            }

            if (quoteToContractMap.isEmpty()) {
                return; // Exit early if there are no quotes associated with the contracts
            }

            // Step 2: Retrieve and update Package__c records
            List<Package__c> packageList = [
                SELECT Id, Contract__c, Quote__c 
                FROM Package__c 
                WHERE Quote__c IN :quoteToContractMap.keySet() AND Installation_Quantity__c > 0
            ];

            for (Package__c packageRecord : packageList) {
                packageRecord.Contract__c = quoteToContractMap.get(packageRecord.Quote__c);
            }

            if (!packageList.isEmpty()) {
                update packageList;
            }

            // Step 3: Retrieve and update Installation__c records
            List<Installation__c> installationList = [
                SELECT Id, Contract__c, Contract__r.SBQQ__Quote__r.SBQQ__Type__c, Package__c, Package__r.Contract__c, 
                Installation_Start_date__c, Installation_End_date__c, Package__r.Quote_Line_Group__c
                FROM Installation__c 
                WHERE Package__c IN :packageList AND Installation_Order_Status__c != 'Terminated'
            ];

            for (Installation__c installationRecord : installationList) {
                installationRecord.Contract__c = installationRecord.Package__r.Contract__c;
                installationRecord.Quote_Line_Group__c = installationRecord.Package__r.Quote_Line_Group__c;
                Contract relatedContract = contractMap.get(installationRecord.Contract__c);
                if (installationRecord.Contract__r.SBQQ__Quote__r.SBQQ__Type__c != 'Renewal') {
                    // installationRecord.Installation_Order_Status__c = 'Active';
                    if (installationRecord.Installation_Start_date__c == null && installationRecord.Installation_End_date__c == null) {
                        if (relatedContract != null) {
                            installationRecord.Installation_Start_date__c = relatedContract.StartDate;
                            installationRecord.Installation_End_date__c = relatedContract.EndDate;
                        }
                    }
                } else {
                    installationRecord.Installation_End_date__c = relatedContract.EndDate;
                }
            }

            if (!installationList.isEmpty()) {
                update installationList;
            }
        } catch (Exception ex) {
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
        }
    }

    public static void activate(List<Installation__c> instList) {
        try {
            List<Id> instIdList = new List<Id>();
            List<Installation__c> newQTInstList = new List<Installation__c>();
            if (instList != null && !instList.isEmpty()) {
                for (Installation__c inst : instList) {
                    inst.Installation_Order_Status__c = 'Active';
                    inst.Installation_End_date__c = Date.valueOf(inst.Contract__r.EndDate);
                    inst.Quote__c = inst.Order__r.SBQQ__Quote__c;
                    if (inst.Contract__r.SBQQ__Quote__r.SBQQ__Type__c != 'Renewal') {
                        inst.Installation_Start_date__c = Date.valueOf(inst.Contract__r.StartDate);
                        if(inst.Contract__r.SBQQ__Quote__r.SBQQ__Type__c == 'Quote')
                        {
                            newQTInstList.add(inst);
                        }
                    } else if (inst.Contract__r.SBQQ__Quote__r.SBQQ__Type__c == 'Renewal' || inst.Contract__r.SBQQ__Quote__r.SBQQ__Type__c == 'Quote') {
                        newQTInstList.add(inst);
                    }
                    instIdList.add(inst.Id);
                }
                CreateInstallationsController.goToInstallationLineCreation(instIdList);
                update instList;
                if (!newQTInstList.isEmpty()) {
                    CreateSalesOrderService.createSORecords(newQTInstList);
                    // CreateSalesOrderService.createSOIRecords(newQTInstList);
                }
            }
        } catch (Exception ex) {
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
        }
    }

    public static void updateSubscriptionValue(List<Contract> newContrList, Map<Id, Contract> oldContrMap) {
        List<AggregateResult> agrList = [SELECT SBQQ__Contract__c, SUM(SBQQ__NetPrice__c) FROM SBQQ__Subscription__c WHERE SBQQ__Contract__c IN :oldContrMap.keySet() GROUP BY SBQQ__Contract__c];
        Map<Id, Decimal> subMap = new Map<Id, Decimal>();
        if (agrList != null && !agrList.isEmpty()) {
            for (AggregateResult agr : agrList) {
                subMap.put((Id)agr.get('SBQQ__Contract__c'), (Decimal)agr.get('expr0'));
            }
            for (Contract con : newContrList) {
                if (con.Status == 'Activated' && oldContrMap.get(con.Id).Status != 'Activated') {
                    con.Subscription_Value__c = subMap.get(con.Id);
                }
            }
        }
    }
}