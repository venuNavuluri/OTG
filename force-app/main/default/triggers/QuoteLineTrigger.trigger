trigger QuoteLineTrigger on SBQQ__QuoteLine__c (before insert, after insert, before update, after update)
{
    if(Trigger.isAfter && Trigger.isInsert)
    {
        new QuoteLineTriggerHandler().afterinsert();
    }
    if(Trigger.isBefore && Trigger.isInsert)
    {
        new QuoteLineTriggerHandler().beforeinsert();
    }
}