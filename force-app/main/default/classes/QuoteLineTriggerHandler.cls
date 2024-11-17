public class QuoteLineTriggerHandler extends TriggerHandler
{
    public override void beforeInsert() {
        QuoteLineTriggerHandler.updateQuoteLineGroupDetails((List<SBQQ__QuoteLine__c>)Trigger.new);
    }
    
    public override void afterInsert() {
        //Map<Id, SBQQ__QuoteLine__c> QLNewMap = (Map<Id, SBQQ__QuoteLine__c>)Trigger.newMap;
       // updateQuoteLineGroupDetails(QLNewMap.keySet());
    }
    
    public static void updateQuoteLineGroupDetails(List<SBQQ__QuoteLine__c> newQuoteLineList)
    {
        Map<Id, Id> qlqtIdMap = new Map<Id, Id>();
        Map<String, SBQQ__QuoteLineGroup__c> qlgNameMap = new Map<String, SBQQ__QuoteLineGroup__c>();
        
        for(SBQQ__QuoteLine__c ql : newQuoteLineList)
        {
            qlqtIdMap.put(ql.Id, ql.SBQQ__Quote__c);
        }
        
        List<SBQQ__QuoteLineGroup__c> qlgList = [SELECT Id, Name, Package__c, Installation_Quantity__c, SBQQ__Number__c, SBQQ__ListTotal__c, SBQQ__CustomerTotal__c, SBQQ__NetTotal__c, SBQQ__Quote__c FROM SBQQ__QuoteLineGroup__c WHERE (SBQQ__Quote__r.SBQQ__Type__c = 'Renewal' OR SBQQ__Quote__r.SBQQ__Type__c = 'Amendment') AND SBQQ__Quote__c IN :qlqtIdMap.values()];
        System.debug('qlgList --> ' + qlgList);
        if(!qlgList.isEmpty())
        {
            for(SBQQ__QuoteLineGroup__c qlg : qlgList)
            {
                qlgNameMap.put(qlg.Name, qlg);
            }
            System.debug('newQuoteLineList --> ' + newQuoteLineList);
            for(SBQQ__QuoteLine__c ql : newQuoteLineList)
            {
                if(ql.SBQQ__Group__c == NULL)
                {
                    ql.SBQQ__Group__c = qlgNameMap.get(ql.Group_Name__c) != NULL ? qlgNameMap.get(ql.Group_Name__c).Id : NULL;
                }
            }
        }

}
    
}