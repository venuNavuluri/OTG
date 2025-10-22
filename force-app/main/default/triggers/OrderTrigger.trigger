trigger OrderTrigger on Order (before insert, after insert, after update)
{
    VRConfiguration__c bypassTrig = VRConfiguration__c.getInstance();
    if (bypassTrig != null && bypassTrig.ByPass_Order_Triggers__c) {
        System.debug('OrderTrigger Trigger skipped for user: ');
        return;
    }

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