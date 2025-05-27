trigger QuoteTrigger on SBQQ__Quote__c (before insert, after insert, before update, after update)
{
    if(Trigger.isAfter && Trigger.isUpdate)
    {
        new QuoteTriggerHandler().afterUpdate(/*Trigger.newMap, Trigger.oldMap*/);
    }
    if(Trigger.isInsert && Trigger.isBefore)
    {
        new QuoteTriggerHandler().beforeinsert();
        QuoteTriggerHandler.handleBeforeInsert(Trigger.new);
    }
    if(Trigger.isAfter && Trigger.isInsert)
    {
        new QuoteTriggerHandler().afterinsert();
        //QuoteTriggerHandler.handleAfterInsert(Trigger.new);
    }
    if(Trigger.isBefore && Trigger.isUpdate)
    {
        new QuoteTriggerHandler().beforeUpdate(/*Trigger.newMap, Trigger.oldMap*/);
    }
}