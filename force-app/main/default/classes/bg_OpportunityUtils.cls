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
    
    public static void CalculateOpportunityNames(List<Opportunity> opps)
    {
        Map<Id, Account> accountsByOppId = GetAccountsByOppId(opps);
        
        for (Opportunity opp : opps)
        {
            opp.Name = CalculateOpportunityName(opp, accountsByOppId);
        }
    }
    
    private static String CalculateOpportunityName(Opportunity opp, Map<Id, Account> accountsByOppId)
    {
        Account acc = accountsByOppId.get(opp.Id);
        
        String customerStatus = opp.Account_Customer_Status__c != null ? CalculateAccountStatus(opp.Account_Customer_Status__c) : CalculateAccountStatus(acc.Customer_Status__c);
        String existingOppType = opp.Existing_Opportunity_Type__c != null ? opp.Existing_Opportunity_Type__c : '';
        Datetime oppNameDate = opp.CreatedDate != null ? opp.CreatedDate : Datetime.now();
        String businessUnit = opp.Business_Unit__c != null ? getBusinessUnitShortName(opp.Business_Unit__c) : '';
        
        return businessUnit + '/ ' + customerStatus + '/ ' + existingOppType + '/ ' + acc.Name.left(50) + '/ ' + oppNameDate.format('yyyy-MM-dd');
    }
    
    private static String getBusinessUnitShortName(String businessUnit) {
        if (businessUnit == null) return '';
        
        switch on businessUnit {
            when 'Voyage Performance & Optimization' {return 'VPO';}
            when 'Voyage Management' {return 'VMS';}
            when 'HCM Crew' {return 'HCM Crew';}
            when 'HCM Learning, Assessment and Competency' {return 'HCM LAC';}
            when 'Technical Ship Management' {return 'TSM';}
            when 'Governance, Risk & Compliance' {return 'GRC';}
            when 'Cloud Fleet Manager' {return 'CFM';}
            when 'API' {return 'API';}
            when else {return businessUnit; }
        }
    }
    
    private static Map<Id, Account> GetAccountsByOppId(List<Opportunity> opps)
    {
        Set<Id> accountIds = new Set<Id>();
        for (Opportunity opp : opps)
        {
            accountIds.add(opp.AccountId);
        }
        
        Map<Id, Account> relatedAccountsMap = new Map<Id, Account>([SELECT Id, Name, Customer_Status__c 
                                                                    FROM Account 
                                                                    WHERE Id IN :accountIds]);
        
        Map<Id, Account> accountsByOppId = new Map<Id, Account>();
        
        for (Opportunity opp : opps)
        {
            accountsByOppId.put(opp.Id, relatedAccountsMap.get(opp.AccountId));
        }
        
        return accountsByOppId;
    }
    
    private static String CalculateAccountStatus(String customerStatus)
    {
        if (customerStatus == 'Prospect' || customerStatus == 'Lost' || customerStatus == 'Lapsed')
        {
            return 'New Customer';
        }
        if (customerStatus == 'Active')
        {
            return 'Existing Customer';
        }
        return '';
    }
    
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