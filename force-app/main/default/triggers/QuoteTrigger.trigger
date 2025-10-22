trigger QuoteTrigger on SBQQ__Quote__c (before insert, after insert, before update, after update)
{
    VRConfiguration__c bypassTrig = VRConfiguration__c.getInstance();
    if (bypassTrig != null && bypassTrig.ByPass_Quote_Triggers__c) {
        System.debug('QuoteTrigger Trigger skipped for user: ' );
        return;
    }
    
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