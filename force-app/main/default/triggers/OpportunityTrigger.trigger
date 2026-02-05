trigger OpportunityTrigger on Opportunity (
    before insert,
    before update,
    before delete,
    after insert,
    after update,
    after delete,
    after undelete
) {
    // Respect org-wide bypass framework (Hierarchy + txn)
    if (AutomationBypass.bypassTriggers('TRG:Opportunity')) return;

    // Guard against recursion is handled inside the handler
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            OpportunityTriggerHandler.beforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            OpportunityTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            OpportunityTriggerHandler.afterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            OpportunityTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}