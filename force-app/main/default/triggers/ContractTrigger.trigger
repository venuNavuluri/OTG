trigger ContractTrigger on Contract (after insert, after update, before update, before insert)
{
    VRConfiguration__c bypassTrig = VRConfiguration__c.getInstance();
    if (bypassTrig != null && bypassTrig.ByPass_Contract_Triggers__c) {
        System.debug('ContractTrigger Trigger skipped for user: ');
        return;
    }

    if(Trigger.isAfter && Trigger.isInsert)
    {
        ContractTriggerHandler.onAfterInsert();
    }
    if(Trigger.isAfter && Trigger.isUpdate)
    {
        ContractTriggerHandler.onAfterUpdate();
    }
    if(Trigger.isBefore)
    {
        if(Trigger.isUpdate)
        {
            ContractTriggerHandler.onBeforeUpdate();
        }
        if(Trigger.isInsert)
        {
            ContractTriggerHandler.onBeforeInsert();
        }
    }
}