/*****************************************************************
* bg_OpportunityUtils
*
* Utils class for Opportunity object
* 
* Test class: bg_OpportunityUtils_Test
*
* Author: Ben Riminton
* Created: 03-09-2021
******************************************************************/

public with sharing class bg_OpportunityUtils {
    public static void handleBeforeUpdate(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        for (Opportunity opp : newList) {
            Opportunity oldOpp = oldMap.get(opp.Id);
            
            if (opp.StageName != oldOpp.StageName) {
                
                Integer oldStageOrder = getStageOrder(oldOpp.StageName);
                Integer newStageOrder = getStageOrder(opp.StageName);
                
                if ((oldOpp.StageName == 'Proposal Review' || oldOpp.StageName == 'Negotiation / Contracting') && newStageOrder < oldStageOrder) {
                    
                    if (opp.Approval_Status__c != null && 
                        (opp.Approval_Status__c.equalsIgnoreCase('Approved') || 
                         opp.Approval_Status__c.equalsIgnoreCase('Rejected') || 
                         opp.Approval_Status__c.equalsIgnoreCase('Recall'))) {
                             opp.Approval_Status__c = null;
                         }
                }
            }
        }
    }
    private static Integer getStageOrder(String stageName) {
        Map<String, Integer> stageOrderMap = new Map<String, Integer>{
            'Prospecting & Qualifying' => 1,
                'Value Proposition' => 2,
                'Proposal / Quote' => 3,
                'Proposal Review' => 4,
                'Negotiation / Contracting' => 5,
                'Closed Won' => 6,
                'Closed Lost' => 7,
                'Completed' => 8
                };
                    
                    return stageOrderMap.containsKey(stageName) ? stageOrderMap.get(stageName) : 0;
    }
}
