public class CompleteAmendmentCreationController
{
    @AuraEnabled
    public static String createQuoteLineGroups(Id quoteId)
    {
        try
        {
            Map<Id, SBQQ__Quote__c> qtMap = new Map<Id, SBQQ__Quote__c>([SELECT Id, Name, SBQQ__Type__c, SBQQ__MasterContract__c, SBQQ__Opportunity2__c FROM SBQQ__Quote__c WHERE Id = :quoteId AND Amendment_Complete__c = TRUE]);
            new QuoteTriggerHandler().createQuoteLineGroups(qtMap);
            SBQQ__Quote__c qt = new SBQQ__Quote__c(Id = quoteId, Amendment_Complete__c = TRUE);
            update qt;
            return 'SUCCESS';
        }
        catch(Exception ex)
        {
            System.debug('ex --> ' + ex);
            return ex.getMessage();
        }
    }
}