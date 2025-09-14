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
    
    List<Opportunity> oppsToGenerateName = new List<Opportunity>();
    
    for (Opportunity opp : Trigger.new)
    {
        Opportunity oldOpp = Trigger.oldMap.get(opp.Id);
        
        Boolean nameFieldChanged = opp.Name != oldOpp.Name || 
            opp.Account_Name__c != oldOpp.Account_Name__c || 
            opp.Customer_Status__c != oldOpp.Customer_Status__c || 
            opp.Existing_Opportunity_Type__c != oldOpp.Existing_Opportunity_Type__c || 
            opp.AccountId != oldOpp.AccountId ||
            opp.Account_Customer_Status__c != oldOpp.Account_Customer_Status__c ||
            opp.Business_Unit__c != oldOpp.Business_Unit__c;
        
        if (nameFieldChanged)
        {
            oppsToGenerateName.add(opp);
        }
    }
    
    if (!oppsToGenerateName.isEmpty())
    {
        bg_OpportunityUtils.CalculateOpportunityNames(oppsToGenerateName);
    }
    
    if (Trigger.isBefore && Trigger.isUpdate) {
        bg_OpportunityUtils.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
        UpdateContractAmended.updateAmendContract(Trigger.new, Trigger.oldMap);
    }  
    
    if (Trigger.isBefore && Trigger.isInsert) {
        UpdateContractAmended.updateAmendContract(Trigger.new, NULL);
    }
}