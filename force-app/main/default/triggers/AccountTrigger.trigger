trigger AccountTrigger on Account (
    before insert,
    before update,
    before delete,
    after insert,
    after update,
    after delete,
    after undelete
) {
    if (AutomationBypass.bypassTriggers('TRG:Account')) return;

    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            AccountTriggerHandler.beforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            AccountTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        } else if (Trigger.isDelete) {
            AccountTriggerHandler.beforeDelete(Trigger.old);
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            AccountTriggerHandler.afterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            AccountTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
        } else if (Trigger.isDelete) {
            AccountTriggerHandler.afterDelete(Trigger.old);
        } else if (Trigger.isUndelete) {
            AccountTriggerHandler.afterUndelete(Trigger.new);
        }
    }
}
