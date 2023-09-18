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
        String businessUnit = opp.Business_Unit__c != null ? opp.Business_Unit__c : '';

        return businessUnit + '/ ' + customerStatus + '/ ' + existingOppType + '/ ' + acc.Name.left(50) + '/ ' + oppNameDate.format('yyyy-MM-dd');
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
}