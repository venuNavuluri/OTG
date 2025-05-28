trigger AgentRelationshipTrigger on Agent_Relationship__c (before insert, before update, after insert) {
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