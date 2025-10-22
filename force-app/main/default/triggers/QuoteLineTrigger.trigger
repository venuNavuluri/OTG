trigger QuoteLineTrigger on SBQQ__QuoteLine__c (before insert, after insert, before update, after update)
{
    VRConfiguration__c bypassTrig = VRConfiguration__c.getInstance();
    if (bypassTrig != null && bypassTrig.ByPass_Quote_Triggers__c) {
        System.debug('QuoteTrigger Trigger skipped for user: ');
        return;
    }

    if(Trigger.isAfter && Trigger.isInsert)
    {
        new QuoteLineTriggerHandler().afterinsert();
    }
    if(Trigger.isBefore && Trigger.isInsert)
    {
        new QuoteLineTriggerHandler().beforeinsert();
    }
}