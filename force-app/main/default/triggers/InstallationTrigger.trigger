trigger InstallationTrigger on Installation__c (before insert)
{
    if(Trigger.isBefore && Trigger.isInsert)
    {
        InstallationTriggerHandler.beforeInsert(Trigger.new);
    }
}