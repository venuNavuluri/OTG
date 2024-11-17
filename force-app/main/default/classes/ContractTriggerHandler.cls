public class ContractTriggerHandler
{
    public static void onBeforeInsert()
    {
        updatePreviousContract((List<Contract>)Trigger.new);
    }
    public static void onBeforeUpdate()
    {
        updatePreviousContract((List<Contract>)Trigger.new);
    }
    public static void onAfterInsert()
    {
        updateContractDetails((Map<Id, Contract>)Trigger.newMap);
        updateNextContract((Map<Id, Contract>)Trigger.newMap);
    }
    
    public static void onAfterUpdate()
    {
        // Retrieve the current user's alias
            String currentUserAlias = [SELECT Alias FROM User WHERE Id = :UserInfo.getUserId()].Alias;
            
            // Bypass the logic if the current user alias is 'duser'
            if (currentUserAlias == 'duser') {
                return; // Exit the method
            }
        try
        {
            Map<Id, Contract> newContrMap = (Map<Id, Contract>)Trigger.newMap;
            Map<Id, Contract> oldContrMap = (Map<Id, Contract>)Trigger.oldMap;
            List<Id> activeContrList = new List<Id>();
            Map<Id, Contract> contrMap = new Map<Id, Contract>([SELECT Id, Name, SBQQ__Quote__c, SBQQ__Quote__r.SBQQ__Type__c FROM Contract WHERE Id IN :newContrMap.keySet()]);
            for(Contract contr : newContrMap.values())
            {
                if((contrMap.get(contr.Id).SBQQ__Quote__r.SBQQ__Type__c == 'Renewal' || contrMap.get(contr.Id).SBQQ__Quote__r.SBQQ__Type__c == 'Quote') && contr.Status == 'Activated' && oldContrMap.get(contr.Id).Status != 'Activated')
                {
                    activeContrList.add(contr.Id);
                }
            }
            List<Installation__c> instList = [SELECT Id, Name, Contract__c, Contract__r.SBQQ__Quote__r.SBQQ__Type__c, Contract__r.StartDate, Contract__r.EndDate, Order__c, Order__r.SBQQ__Quote__c, Quote_Line_Group__r.SBQQ__Quote__c, Order__r.ActivatedDate FROM Installation__c WHERE Contract__c IN :activeContrList ORDER BY CreatedDate DESC];
            activate(instList);
            updateNextContract((Map<Id, Contract>)Trigger.newMap);
        }
        catch(Exception ex)
        {
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
        }
    }
    
    public static void updatePreviousContract(List<Contract> newContrList)
    {
        // Retrieve the current user's alias
            String currentUserAlias = [SELECT Alias FROM User WHERE Id = :UserInfo.getUserId()].Alias;
            
            // Bypass the logic if the current user alias is 'duser'
            if (currentUserAlias == 'duser') {
                return; // Exit the method
            }
        try
        {
            List<Id> qtIdList = new List<Id>();
            Map<Contract, Id> contrOppIdMap = new Map<Contract, Id>();
            for(Contract con : newContrList)
            {
                if(con.SBQQ__Quote__c != NULL && con.SBQQ__Opportunity__c != NULL && con.Previous_Contract__c == NULL)
                {
                    qtIdList.add(con.SBQQ__Quote__c);
                    contrOppIdMap.put(con, con.SBQQ__Opportunity__c);
                }
            }
            Map<Id, SBQQ__Quote__c> qtMap = new Map<Id, SBQQ__Quote__c>([SELECT Id, Name, SBQQ__Type__c, Agreement_Type__c, SBQQ__BillingFrequency__c FROM SBQQ__Quote__c WHERE Id IN :qtIdList]);
            Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>([SELECT Id, Name, SBQQ__RenewedContract__c, SBQQ__RenewedContract__r.Unit_of_Measure__c, Number_of_Installations__c, Business_Unit__c, Legal_Entity__c, Sales_Type__c, LeadSource, SBQQ__PrimaryQuote__c, SBQQ__PrimaryQuote__r.SBQQ__DeliveryMethod__c,SBQQ__PrimaryQuote__r.SBQQ__StartDate__c, SBQQ__PrimaryQuote__r.SBQQ__EndDate__c FROM Opportunity WHERE Id IN :contrOppIdMap.values()]);
            
            for(Contract con : newContrList)
            {
                if(qtMap.get(con.SBQQ__Quote__c) != NULL)
                {
                    Opportunity opp = oppMap.get(con.SBQQ__Opportunity__c);
                    con.Legal_Entity__c = opp.Legal_Entity__c; 
                    con.No_of_Installations__c = opp.Number_of_Installations__c;
                    con.Business_Unit__c = opp.Business_Unit__c;
                    con.Unit_of_Measure__c = qtMap.get(con.SBQQ__Quote__c).Agreement_Type__c;
                    con.Default_Delivery_Method__c = opp.SBQQ__PrimaryQuote__r.SBQQ__DeliveryMethod__c;
                    If(qtMap.get(con.SBQQ__Quote__c).SBQQ__Type__c == 'Renewal')
                    {
                        con.StartDate = opp.SBQQ__PrimaryQuote__r.SBQQ__StartDate__c;
                        con.EndDate = opp.SBQQ__PrimaryQuote__r.SBQQ__EndDate__c;
                        con.Previous_Contract__c = opp.SBQQ__RenewedContract__c;
                    }
                    con.Billing_Frequency__c = qtMap.get(con.SBQQ__Quote__c).SBQQ__BillingFrequency__c;
                }
            }
        }
        catch(Exception ex)
        {
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
        }
    }
    
    public static void updateNextContract(Map<Id, Contract> newContrMap)
    {
        try
        {
            List<Contract> contrList = new List<Contract>();
            for(Contract contr : newContrMap.values())
            {
                if(contr.Previous_Contract__c != NULL)
                {
                    Contract ct = new Contract(
                        Id = contr.Previous_Contract__c,
                        Next_Contract__c = contr.Id
                    );
                    contrList.add(ct);
                }
            }
            if(!contrList.isEmpty())
            {
                update contrList;
            }
        }
        catch(Exception ex)
        {
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
        }
    }
    
    public static void updateContractDetails(Map<Id, Contract> contractMap)
    {
        // Retrieve the current user's alias
            String currentUserAlias = [SELECT Alias FROM User WHERE Id = :UserInfo.getUserId()].Alias;
            
            // Bypass the logic if the current user alias is 'duser'
            if (currentUserAlias == 'duser') {
                return; // Exit the method
            }
        try
        {
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
                WHERE Quote__c IN :quoteToContractMap.keySet()
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
                Installation_Start_date__c, Installation_End_date__c 
                FROM Installation__c 
                WHERE Package__c IN :packageList
            ];
            
            for (Installation__c installationRecord : installationList) {
                installationRecord.Contract__c = installationRecord.Package__r.Contract__c;
                Contract relatedContract = contractMap.get(installationRecord.Contract__c);
                if(installationRecord.Contract__r.SBQQ__Quote__r.SBQQ__Type__c != 'Renewal')
                {
                    //installationRecord.Installation_Order_Status__c = 'Active';
                    if (installationRecord.Installation_Start_date__c == null && installationRecord.Installation_End_date__c == null)
                    {
                        if (relatedContract != null)
                        {
                            installationRecord.Installation_Start_date__c = relatedContract.StartDate;
                            installationRecord.Installation_End_date__c = relatedContract.EndDate;
                        }
                    }
                }
                else
                {
                    installationRecord.Installation_End_date__c = relatedContract.EndDate;
                }
            }
            
            if (!installationList.isEmpty()) {
                update installationList;
            }
        }
        catch(Exception ex)
        {
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
        }
    }
    
    public static void activate(List<Installation__c> instList)
    {
        try
        {
            List<Id> instIdList = new List<Id>();
            List<Installation__c> newQTInstList = new List<Installation__c>();
            if(instList != NULL && !instList.isEmpty())
            {
                for(Installation__c inst : instList)
                {
                    inst.Installation_Order_Status__c = 'Active';
                    inst.Installation_End_date__c = Date.valueOf(inst.Contract__r.EndDate);
                    inst.Quote__c = inst.Order__r.SBQQ__Quote__c;
                    if(inst.Contract__r.SBQQ__Quote__r.SBQQ__Type__c != 'Renewal')
                    {
                        inst.Installation_Start_date__c = Date.valueOf(inst.Contract__r.StartDate);
                    }
                    else if(inst.Contract__r.SBQQ__Quote__r.SBQQ__Type__c == 'Renewal')
                    {
                        newQTInstList.add(inst);
                    }
                    instIdList.add(inst.Id);
                }
                CreateInstallationsController.goToInstallationLineCreation(instIdList);
                update instList;
                if(!newQTInstList.isEmpty())
                {
                    CreateSalesOrderService.createSORecords(newQTInstList);
                    //CreateSalesOrderService.createSOIRecords(newQTInstList);
                }
            }
        }
        catch(Exception ex)
        {
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
        }
    }
    
}