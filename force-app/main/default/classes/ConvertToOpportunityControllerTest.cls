@IsTest
public class ConvertToOpportunityControllerTest
{
    @IsTest
    public static void test1()
    {
    
    Default_Account_Owner_Settings__c setting = new Default_Account_Owner_Settings__c();
      setting.SetupOwnerId=UserInfo.getOrganizationId();
     setting.Name = 'EMEA Default Owner ID';
    setting.EMEA_Default_Owner_ID__c     = '005Si0000004LInIAM';
     insert setting;
     
        Country_Mapping__c cm = new Country_Mapping__c();
        cm.Name = 'Test';
        cm.Sales_Region__c = 'Americas';
        insert cm;
        
        Account acc = new Account();
        acc.Name = 'Test';
        acc.Account_Status__c = 'Unverified';
        acc.AccountSource = 'Cross Department Referral';
        acc.Address1__c = 'Test';
        acc.Town_City__c = 'Texas';
        acc.Country__c = cm.Id;
        acc.Account_Segmentation__c = 'Unknown';
        acc.Customer_Type__c = 'Charity';
        insert acc;
        
        Contact con = new Contact();
        con.LastName = 'Test con';
        con.AccountId = acc.Id;
        con.Job_Role__c = 'Crew / Seafarer';
        insert con;
        Lead ld = new Lead(
            LastName = 'Test',
            Status = 'New',
            Phone = '9685741230',
            MobilePhone = '9685741230',
            Company = 'Test',
            LeadSource = 'Cross Department Referral',
            Products__c = 'Learning & Assessment',
            Description = 'Test desc',
            Account__c = acc.Id,
            Contact__c = con.Id
        );
        insert ld;
        
        ConvertToOpportunityController.convertToOpportunity((String)ld.Id);
    }
}