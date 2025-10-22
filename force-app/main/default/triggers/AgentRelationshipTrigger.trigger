trigger AgentRelationshipTrigger on Agent_Relationship__c (before insert, before update, after insert) {
    VRConfiguration__c bypassTrig = VRConfiguration__c.getInstance();
    if (bypassTrig != null && bypassTrig.ByPass_Account_Triggers__c) {
        System.debug('AgentRelationshipTrigger Trigger skipped for user: ');
        return;
    }

    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
           AgentRelationshipTriggerHandler.handleBeforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
           AgentRelationshipTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
    if (Trigger.isAfter && Trigger.isInsert) {
        AgentRelationshipTriggerHandler.handleAfterInsert(Trigger.new); 
    }
}