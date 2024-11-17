public class OrderTriggerHandler
{
    public static void onBeforeInsert(List<Order> orderList)
    {
        validateInstallationCount(orderList);
    }
    
    public static void onAfterInsert(Map<Id, Order> orderMap)
    {
        createContract(orderMap.keySet());
    }
    
    public static void onAfterUpdate(Map<Id, Order> oldOrderMap, List<Order> newOrderList)
    {
        List<Order> ordToCreateInst = new List<Order>();
        for(Order ord : newOrderList)
        {
            if(ord.Status == 'Activated' && (ord.Status != oldOrderMap.get(ord.Id).Status))
            {
                ordToCreateInst.add(ord);
            }
        }
        System.debug('ordToCreateInst --> ' + ordToCreateInst);
        updateOrderIdOnInstallation(ordToCreateInst);
    }
    
    public static void validateInstallationCount(List<Order> orderList)
    {
        try
        {
            Map<Id, Order> qtIdOrderMap = new Map<Id, Order>();
            for(Order ord : orderList)
            {
                qtIdOrderMap.put(ord.SBQQ__Quote__c, ord);
            }
            List<Package__c> packList = [SELECT Id, Name, Quote__c, Quote__r.Auto_Installation__c, Quote__r.Auto_Termination__c, Installation_Quantity__c, (SELECT Id, Name FROM Installations__r WHERE Installation_Order_Status__c != 'Terminated') CreatedDate FROM Package__c WHERE Quote__c IN :qtIdOrderMap.keySet() AND Contract__r.Migrated_Contract__c != TRUE ORDER BY CreatedDate DESC];
            for(Package__c pack : packList)
            {
                if(!pack.Quote__r.Auto_Installation__c && !pack.Quote__r.Auto_Termination__c && pack.Installations__r != NULL && (pack.Installation_Quantity__c != pack.Installations__r.size()))
                {
                    qtIdOrderMap.get(pack.Quote__c).addError('No. of active installations on package must match with the Installation Quantity on package');
                }
            }
        }
        catch(Exception ex)
        {
            Logger.error(ex.getMessage());
        }
    }
    
    @future
    public static void createContract(Set<Id> orderIdSet)
    {
        try
        {
            List<Order> orderList = [SELECT Id, Name, SBQQ__Quote__c FROM Order WHERE Id IN :orderIdSet];
            List<Id> qtIdList = new List<Id>();
            for(Order ord : orderList)
            {
                qtIdList.add(ord.SBQQ__Quote__c);
            }
            Map<Id, SBQQ__Quote__c> qtMap = new Map<Id, SBQQ__Quote__c>([SELECT Id, Name, SBQQ__BillingFrequency__c, SBQQ__SubscriptionTerm__c, SBQQ__Type__c, Auto_Installation__c, Auto_Termination__c, SBQQ__StartDate__c, SBQQ__EndDate__c FROM SBQQ__Quote__c WHERE Id IN :qtIdList]);
            List<Order> ordUpdateList = new List<Order>();
            for(Order ord : orderList)
            {
                ord.Billing_Frequency__c = qtMap.get(ord.SBQQ__Quote__c).SBQQ__BillingFrequency__c;
                if(qtMap.get(ord.SBQQ__Quote__c).Auto_Termination__c || qtMap.get(ord.SBQQ__Quote__c).SBQQ__Type__c == 'Renewal' )//need to add renewal logic
                {
                    ord.EffectiveDate = qtMap.get(ord.SBQQ__Quote__c).SBQQ__StartDate__c;
                    //ord.EndDate	 = qtMap.get(ord.SBQQ__Quote__c).SBQQ__EndDate__c;
                    ord.SBQQ__RenewalTerm__c = qtMap.get(ord.SBQQ__Quote__c).SBQQ__SubscriptionTerm__c;
                    ord.Status = 'Activated';
                    ord.SBQQ__Contracted__c = TRUE;
                    ordUpdateList.add(ord);
                }
                else if(qtMap.get(ord.SBQQ__Quote__c).Auto_Installation__c)
                {
                    ord.Status = 'Pending Implementation';
                    ordUpdateList.add(ord);
                }
            }
            System.debug('ordList --> ' + ordUpdateList);
            if(!ordUpdateList.isEmpty())
            {
                update ordUpdateList;
            }
        }
        catch(Exception ex)
        {
            Logger.error(ex.getMessage());
            Logger.saveLog();
        }
    }
    
    public static void updateOrderIdOnInstallation(List<Order> orderList)
    {
        try
        {
            Map<Id, Order> qtIdOrdMap = new Map<Id, Order>();
            for(Order ord : orderList)
            {
                qtIdOrdMap.put(ord.SBQQ__Quote__c, ord);
            }
            List<Installation__c> instList = new List<Installation__c>();
            Map<Id, SBQQ__Quote__c> qtMap = new Map<Id, SBQQ__Quote__c>([SELECT Id, Name, Installation__c FROM SBQQ__Quote__c WHERE Id IN :qtIdOrdMap.keySet() AND Installation__c != NULL]);
            if(!qtMap.isEmpty())
            {
                for(Order ord : orderList)
                {
                    Installation__c inst = new Installation__c();
                    //inst.Installation_Order_Status__c = 'Active';
                    inst.Order__c = ord.Id;
                    inst.Installation_Start_date__c = Date.today();
                    inst.Id = qtMap.get(ord.SBQQ__Quote__c).Installation__c;
                    instList.add(inst);
                }
            }
            if(instList != NULL && !instList.isEmpty())
            {
                update instList;
            }
        }
        catch(Exception ex)
        {
            Logger.error(ex.getMessage());
            Logger.saveLog();
        }
    }
}