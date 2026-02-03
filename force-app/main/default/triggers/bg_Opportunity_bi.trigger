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
    bg_OpportunityUtils.CalculateOpportunityNames(Trigger.new);
}