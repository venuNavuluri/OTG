public with sharing class ShowChangeTypesController {

    @AuraEnabled(cacheable=TRUE)
    public static List<SBQQ__QuoteLineGroup__c> getQuoteLineGroups(String qtId)
    {
        System.debug('qtId --> ' + qtId);
        List<SBQQ__QuoteLineGroup__c> qlgList = [SELECT Id, Name, CurrencyISOCode, Installation_Price__c, Product_Change_Type__c, InstallationChangeType__c, Installation_Change_Type__c FROM SBQQ__QuoteLineGroup__c WHERE SBQQ__Quote__c = :qtId];
        for(SBQQ__QuoteLineGroup__c qlg : qlgList)
        {
            if(qlg.Product_Change_Type__c == NULL)
            {
                qlg.Product_Change_Type__c = 'No Change';
            }
            if(qlg.Installation_Change_Type__c == NULL)
            {
                qlg.Installation_Change_Type__c = 'No Change';
            }
            if(qlg.Installation_Price__c == NULL)
            {
                qlg.Installation_Price__c = 0;
            }
        }
        System.debug('qlgList --> ' + qlgList);
        return qlgList;
    }
}