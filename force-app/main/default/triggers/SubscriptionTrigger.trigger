trigger SubscriptionTrigger on SBQQ__Subscription__c (after insert)
{
    SubscriptionTriggerHandler handler = new SubscriptionTriggerHandler();
    if(Trigger.isafter && Trigger.isInsert)
    {
        handler.afterInsert();
    }
}