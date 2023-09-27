public class QuoteTriggerHelper
{
    public static void updateQlgCheckbox(List<SBQQ__Quote__c> newQuoteList)
    {
        for(SBQQ__Quote__c qt : newQuoteList)
        {
            qt.SBQQ__LineItemsGrouped__c = TRUE;
        }
    }
    
    public static void createDummyQLG(Map<Id, SBQQ__Quote__c> newQuoteMap)
    {
        List<SBQQ__QuoteLineGroup__c> qlgList = new List<SBQQ__QuoteLineGroup__c>();
        for(SBQQ__Quote__c qt : newQuoteMap.values())
        {
            if(qt.SBQQ__Type__c == 'Quote')
            {
                qlgList.add(new SBQQ__QuoteLineGroup__c(
                    SBQQ__Quote__c = qt.Id,
                    Name = 'Package 1',
                    SBQQ__Number__c = 1,
                    SBQQ__ListTotal__c = 0,
                    SBQQ__CustomerTotal__c = 0,
                    SBQQ__NetTotal__c = 0
                ));
            }
        }
        if(!qlgList.isEmpty())
        {
            insert qlgList;
        }
    }
}