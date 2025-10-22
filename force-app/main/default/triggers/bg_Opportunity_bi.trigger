/*****************************************************************
* bg_Opportunity_bi
*
* Before insert for Opportunity object
* 
*
* Author: Ben Riminton
* Created: 03-09-2021
******************************************************************/

trigger bg_Opportunity_bi on Opportunity (before insert) {
    
    VRConfiguration__c bypassTrig = VRConfiguration__c.getInstance();
    if (bypassTrig != null && bypassTrig.ByPass_Opportunity_Triggers__c) {
        System.debug('bg_Opportunity_bi Trigger skipped for user: ');
        return;
    } 
    
    bg_OpportunityUtils.CalculateOpportunityNames(Trigger.new);
}