trigger QuoteLineTrigger on SBQQ__QuoteLine__c (before insert, after insert, before update, after update)
{ 
    // Respect org-wide bypass framework (Hierarchy + txn)
    if (AutomationBypass.bypassTriggers('TRG:Quote')) return;

    if(Trigger.isAfter && Trigger.isInsert)
    {
        new QuoteLineTriggerHandler().afterinsert();
    }
    if(Trigger.isBefore && Trigger.isInsert)
    {
        new QuoteLineTriggerHandler().beforeinsert();
    }
}