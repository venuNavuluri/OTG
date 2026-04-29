/*****************************************************************
* bg_Opportunity_bu
*
* Before update for Opportunity object
* 
*
* Author: Ben Riminton
* Created: 03-09-2021
******************************************************************/

trigger bg_Opportunity_bu on Opportunity (before update) {
    if (AutomationBypass.bypassTriggers('TRG:Opportunity')) return;
    
    if (Trigger.isBefore && Trigger.isUpdate) {
        bg_OpportunityUtils.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
    }
}
