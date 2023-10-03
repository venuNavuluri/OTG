global class QuoteCloneScheduler implements Schedulable
{
    public Set<Id> qtIdSet = new Set<Id>();
    global void execute(SchedulableContext SC)
    {
        Map<Id, SBQQ__Quote__c> qtMap = new Map<Id, SBQQ__Quote__c>([SELECT Id, Name, SBQQ__Type__c, SBQQ__MasterContract__c, SBQQ__Opportunity2__c FROM SBQQ__Quote__c WHERE Id IN :qtIdSet AND Amendment_Complete__c = FALSE]);
        if(!qtMap.isEmpty())
        {
            new QuoteCloneScheduler().createQuoteLineGroups(qtMap);
        }
    }
    
    public void createQuoteLineGroups(Map<Id, SBQQ__Quote__c> newQtMap)
    {
        Map<Id, Id> qtIdMap = new Map<Id, Id>();
        Map<Id, Id> masterContractIdQtIdMap = new Map<Id, Id>();
        Map<Id, Id> oppIdQtIdMap = new Map<Id, Id>();
        for(SBQQ__Quote__c qt : newQtMap.values())
        {
            if(qt.SBQQ__Type__c == 'Amendment' && qt.SBQQ__MasterContract__c != NULL)
            {
                masterContractIdQtIdMap.put(qt.SBQQ__MasterContract__c, qt.Id);
            }
            else if(qt.SBQQ__Type__c == 'Renewal')
            {
                oppIdQtIdMap.put(qt.SBQQ__Opportunity2__c, qt.Id);
            }
        }
        List<Opportunity> oppList = [SELECT Id, Name, SBQQ__RenewedContract__c FROM Opportunity WHERE Id IN :oppIdQtIdMap.keySet()];
        for(Opportunity opp : oppList)
        {
            masterContractIdQtIdMap.put(opp.SBQQ__RenewedContract__c, oppIdQtIdMap.get(opp.Id));
        }
        System.debug('masterContractIdQtIdMap --> ' + masterContractIdQtIdMap);
        
        List<Contract> contractList = [SELECT Id, Name, SBQQ__Quote__c FROM Contract WHERE Id IN :masterContractIdQtIdMap.keySet()];
        
        for(Contract con : contractList)
        {
            qtIdMap.put(con.SBQQ__Quote__c, masterContractIdQtIdMap.get(con.Id));
        }
        System.debug('qtIdMap --> ' + qtIdMap);
        Map<Id, SBQQ__Quote__c> quoteMap = new Map<Id, SBQQ__Quote__c>([SELECT Id, Name FROM SBQQ__Quote__c WHERE Id IN :qtIdMap.keySet()]);
        List<SBQQ__QuoteLineGroup__c> qlgList = [SELECT Id, Name, Package__c, Installation_Quantity__c, SBQQ__Number__c, SBQQ__ListTotal__c, SBQQ__CustomerTotal__c, SBQQ__NetTotal__c, SBQQ__Quote__c FROM SBQQ__QuoteLineGroup__c WHERE SBQQ__Quote__c IN :qtIdMap.keySet()];
        List<SBQQ__QuoteLine__c> qlList = [SELECT Id, Name, SBQQ__Group__c, Group_Name__c, SBQQ__Quote__c FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c IN :qtIdMap.keySet() ORDER BY Name DESC];
        Map<Id, SBQQ__QuoteLine__c> qlNewMap = new Map<Id, SBQQ__QuoteLine__c>([SELECT Id, Name, SBQQ__Group__c, Group_Name__c, SBQQ__Quote__c FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c IN :qtIdMap.values() ORDER BY Name DESC]);
        //List<Package__c> packList = [SELECT Id, Name, Quote__c FROM Package__c WHERE Quote__c IN :qtIdMap.values()];
        Map<Id, SBQQ__QuoteLineGroup__c> oldQlgNewQlgMap = new Map<Id, SBQQ__QuoteLineGroup__c>();
        Map<String, SBQQ__QuoteLineGroup__c> qlgNameMap = new Map<String, SBQQ__QuoteLineGroup__c>();
        List<SBQQ__QuoteLine__c> qlNewList = new List<SBQQ__QuoteLine__c>();
        
        for(SBQQ__QuoteLineGroup__c qlg : qlgList)
        {
            SBQQ__QuoteLineGroup__c qlgNew = qlg.clone(false, true, false, false);
            qlgNew.SBQQ__Quote__c = qtIdMap.get(qlg.SBQQ__Quote__c);
            oldQlgNewQlgMap.put(qlg.Id, qlgNew);
            qlgNameMap.put(qlgNew.Name, qlgNew);
        }
        System.debug('oldQlgNewQlgMap --> ' + oldQlgNewQlgMap);
        
        if(!oldQlgNewQlgMap.isEmpty())
        {
            insert oldQlgNewQlgMap.values();
        }
        
        for(SBQQ__QuoteLine__c ql : qlNewMap.values())
        {
            ql.SBQQ__Group__c = qlgNameMap.get(ql.Group_Name__c).Id;
            qlNewList.add(ql);
        }
        System.debug('qlNewList --> ' + qlNewList);
        if(!qlNewList.isEmpty())
        {
            update qlNewList;
        }
    }
}