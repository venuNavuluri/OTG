trigger QuoteTrigger on SBQQ__Quote__c (before insert, after insert, before update, after update)
{
    // Respect org-wide bypass framework (Hierarchy + txn)
    if (AutomationBypass.bypassTriggers('TRG:Quote')) return;
    
    if(Trigger.isAfter && Trigger.isUpdate)
    {
        new QuoteTriggerHandler().afterUpdate();
    }
    if(Trigger.isInsert && Trigger.isBefore)
    {
        new QuoteTriggerHandler().beforeinsert();
    }
    if(Trigger.isAfter && Trigger.isInsert)
    {
        new QuoteTriggerHandler().afterinsert();
    }
    if(Trigger.isBefore && Trigger.isUpdate)
    {
        new QuoteTriggerHandler().beforeUpdate();
    }
}