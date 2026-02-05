trigger OrderTrigger on Order (before insert, after insert, after update)
{
    if (AutomationBypass.bypassTriggers('TRG:Order')) return;
    if(Trigger.isBefore && Trigger.isInsert)
    {
        OrderTriggerHandler.onBeforeInsert(Trigger.new);
    }

    if(Trigger.isAfter && Trigger.isInsert)
    {
        OrderTriggerHandler.onAfterInsert(Trigger.newMap);
    }
    
    if(Trigger.isAfter && Trigger.isUpdate)
    {
        OrderTriggerHandler.onAfterUpdate(Trigger.oldMap, Trigger.new);
    }
}