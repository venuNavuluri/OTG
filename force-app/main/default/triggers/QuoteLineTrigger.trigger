trigger QuoteLineTrigger on SBQQ__QuoteLine__c (before insert)
{
    QuoteLineTriggerHandler handler = new QuoteLineTriggerHandler();
    if(Trigger.isBefore && Trigger.isInsert)
    {
        handler.beforeInsert();
    }
}