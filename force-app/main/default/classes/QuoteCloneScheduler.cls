global class QuoteCloneScheduler implements Schedulable
{
    public Set<Id> qtIdSet = new Set<Id>();
    global void execute(SchedulableContext SC)
    {
        Map<Id, SBQQ__Quote__c> qtMap = new Map<Id, SBQQ__Quote__c>([SELECT Id, Name, SBQQ__Type__c, SBQQ__MasterContract__c FROM SBQQ__Quote__c WHERE Id IN :qtIdSet]);
        new QuoteTriggerHandler().createQuoteLineGroups(qtMap);
    }
}