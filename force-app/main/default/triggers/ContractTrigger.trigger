trigger ContractTrigger on Contract (after insert, after update)
{
    if(Trigger.isAfter && Trigger.isInsert)
    {
        ContractTriggerHandler.onAfterInsert();
    }
    if(Trigger.isAfter && Trigger.isUpdate)
    {
        ContractTriggerHandler.onAfterUpdate();
    }
}