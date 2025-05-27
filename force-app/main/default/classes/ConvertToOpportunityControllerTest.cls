@isTest
public class ConvertToOpportunityControllerTest {

    public static void TestData(String productValue) {
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
        
        Lead lead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Company = 'Test Company',
            Account__c = acc.Id,
            Contact__c = con.Id,
            Campaign__c = null,
            Description = 'Test Lead for Opportunity',
            Products__c = productValue
        );
        insert lead;
    }

    @isTest
    public static void fleetConvertToOpportunity() {
        TestData('Fleet Management System (TM Master)');

        Lead testLead = [SELECT Id FROM Lead WHERE Company = 'Test Company' LIMIT 1];
        
        Test.startTest();
        String opportunityId = ConvertToOpportunityController.convertToOpportunity(testLead.Id);
        Test.stopTest();

        Opportunity createdOpp = [SELECT Id, Product_Group__c, Business_Unit__c FROM Opportunity WHERE Id = :opportunityId LIMIT 1];

        System.assertNotEquals(createdOpp, null, 'Opportunity should be created');
        System.assertEquals(createdOpp.Product_Group__c, 'TM Master', 'Product Group should be set based on Lead product');
        System.assertEquals(createdOpp.Business_Unit__c, 'Fleet', 'Business Unit should be Fleet');
    }
    
    @isTest
    public static void crewConvertToOpportunity() {
        TestData('Crew Management/HR System (Compas)');

        Lead testLead = [SELECT Id FROM Lead WHERE Company = 'Test Company' LIMIT 1];

        Test.startTest();
        String opportunityId = ConvertToOpportunityController.convertToOpportunity(testLead.Id);
        Test.stopTest();

        Opportunity createdOpp = [SELECT Id, Product_Group__c, Business_Unit__c FROM Opportunity WHERE Id = :opportunityId LIMIT 1];

        System.assertNotEquals(createdOpp, null, 'Opportunity should be created');
        System.assertEquals(createdOpp.Product_Group__c, 'Compas Core', 'Product Group should be set based on Lead product');
        System.assertEquals(createdOpp.Business_Unit__c, 'Crew', 'Business Unit should be Crew');
    }
    
    @isTest
    public static void marineConvertToOpportunity() {
        TestData('Marine Regulations');

        Lead testLead = [SELECT Id FROM Lead WHERE Company = 'Test Company' LIMIT 1];

        Test.startTest();
        String opportunityId = ConvertToOpportunityController.convertToOpportunity(testLead.Id);
        Test.stopTest();

        Opportunity createdOpp = [SELECT Id, Product_Group__c, Business_Unit__c FROM Opportunity WHERE Id = :opportunityId LIMIT 1];

        System.assertNotEquals(createdOpp, null, 'Opportunity should be created');
        System.assertEquals(createdOpp.Product_Group__c, 'Marine Regulations', 'Product Group should be set based on Lead product');
        System.assertEquals(createdOpp.Business_Unit__c, 'Marine Regulations', 'Business Unit should be Marine Regulations');
    }
}