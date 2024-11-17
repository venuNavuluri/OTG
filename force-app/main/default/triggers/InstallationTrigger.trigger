trigger InstallationTrigger on Installation__c (before insert, after insert, after update)
{
    if(Trigger.isBefore && Trigger.isInsert)
    {
        InstallationTriggerHandler.beforeInsert(Trigger.new);
    }
    
    if(Trigger.isAfter)
    {
        if(Trigger.isInsert)
        {
            //InstallationTriggerHandler.afterInsert(Trigger.new);
        }
        if(Trigger.isUpdate)
        {
            InstallationTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}