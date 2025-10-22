trigger InstallationTrigger on Installation__c (before insert, after insert, after update)
{
    VRConfiguration__c bypassTrig = VRConfiguration__c.getInstance();
    if (bypassTrig != null && bypassTrig.ByPass_Installation_Triggers__c) {
        System.debug('InstallationTrigger Trigger skipped for user: ' );
        return;
    }

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