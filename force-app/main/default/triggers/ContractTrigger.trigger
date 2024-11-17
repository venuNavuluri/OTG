trigger ContractTrigger on Contract (after insert, after update, before update, before insert)
{
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