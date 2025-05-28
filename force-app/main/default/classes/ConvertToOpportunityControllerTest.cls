@isTest
public class ConvertToOpportunityControllerTest {
    
    public static void TestData(String expectedBusinessUnit, String productGroup) {
        // Create default settings
        Default_Account_Owner_Settings__c setting = new Default_Account_Owner_Settings__c();
        setting.SetupOwnerId = UserInfo.getOrganizationId();
        setting.Name = 'EMEA Default Owner ID';
        setting.EMEA_Default_Owner_ID__c = UserInfo.getUserId(); // Use current user
        insert setting;
        
        // Create country mapping
        Country_Mapping__c cm = new Country_Mapping__c();
        cm.Name = 'Test';
        cm.Sales_Region__c = 'Americas';
        insert cm;
        
        // Create test account
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
        
        // Create test contact
        Contact con = new Contact();
        con.LastName = 'Test con';
        con.AccountId = acc.Id;
        con.Job_Role__c = 'Crew / Seafarer';
        insert con;
        
        // Create test campaign
        Campaign camp = new Campaign(
            Name = 'Test Campaign',
            IsActive = true
        );
        insert camp;
        
        // Create test lead - set the fields that the Business_Units__c formula depends on
        Lead lead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Company = 'Test Company',
            Account__c = acc.Id,
            Contact__c = con.Id,
            Campaign__c = camp.Id,
            Description = 'Test Lead for Opportunity',
            Products__c = productGroup,
            LeadSource = 'Web'
        );
        insert lead;
        
        Lead updatedLead = [SELECT Id, Business_Units__c FROM Lead WHERE Id = :lead.Id];
        System.debug('Calculated Business Unit: ' + updatedLead.Business_Units__c);
    }
    
    @isTest
    public static void fleetConvertToOpportunity() {
        TestData('Fleet', 'Fleet Management System (TM Master)');
        
        Lead testLead = [SELECT Id, Business_Units__c FROM Lead WHERE Company = 'Test Company' LIMIT 1];
        System.debug('Test Lead Business Unit: ' + testLead.Business_Units__c);
        
        Test.startTest();
        String opportunityId = ConvertToOpportunityController.convertToOpportunity(testLead.Id);
        Test.stopTest();
        
        Opportunity createdOpp = [SELECT Id, Product_Group__c, Business_Unit__c FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
        
        System.assertNotEquals(null, createdOpp, 'Opportunity should be created');
        System.assertEquals('TM Master', createdOpp.Product_Group__c, 'Product Group should be TM Master');
        System.assertEquals('Fleet', createdOpp.Business_Unit__c, 'Business Unit should be Fleet');
    }
    
    @isTest
    public static void crewConvertToOpportunity() {
        TestData('Crew', 'Crew Management/HR System (Compas)');
        
        Lead testLead = [SELECT Id FROM Lead WHERE Company = 'Test Company' LIMIT 1];
        
        Test.startTest();
        String opportunityId = ConvertToOpportunityController.convertToOpportunity(testLead.Id);
        Test.stopTest();
        
        Opportunity createdOpp = [SELECT Id, Product_Group__c, Business_Unit__c FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
        
        System.assertNotEquals(null, createdOpp, 'Opportunity should be created');
        System.assertEquals('Compas Core', createdOpp.Product_Group__c, 'Product Group should be Compas Core');
        System.assertEquals('Crew', createdOpp.Business_Unit__c, 'Business Unit should be Crew');
    }
    
    @isTest
    public static void marineConvertToOpportunity() {
        TestData('Marine Regulations', 'Marine Regulations');
        
        Lead testLead = [SELECT Id FROM Lead WHERE Company = 'Test Company' LIMIT 1];
        
        Test.startTest();
        String opportunityId = ConvertToOpportunityController.convertToOpportunity(testLead.Id);
        Test.stopTest();
        
        Opportunity createdOpp = [SELECT Id, Product_Group__c, Business_Unit__c FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
        
        System.assertNotEquals(null, createdOpp, 'Opportunity should be created');
        System.assertEquals('Marine Regulations', createdOpp.Product_Group__c, 'Product Group should be Marine Regulations');
        System.assertEquals('Marine Regulations', createdOpp.Business_Unit__c, 'Business Unit should be Marine Regulations');
    }
    
    @isTest
    public static void testErrorHandling() {
        // Create lead without account and contact (should fail)
        Lead lead = new Lead(
            FirstName = 'Test',
            LastName = 'Error',
            Company = 'Test Error Company'
        );
        insert lead;
        
        Test.startTest();
        String result = ConvertToOpportunityController.convertToOpportunity(lead.Id);
        Test.stopTest();
        
        System.assertEquals('Error: Missing Account or Contact reference. Account: null, Contact: null', result, 
                            'Should return error for missing account and contact');
    }
    
    @isTest
    public static void testNullBusinessUnit() {
        TestData(null, null); // No business unit
        
        Lead testLead = [SELECT Id FROM Lead WHERE Company = 'Test Company' LIMIT 1];
        
        Test.startTest();
        String opportunityId = ConvertToOpportunityController.convertToOpportunity(testLead.Id);
        Test.stopTest();
        
        Opportunity createdOpp = [SELECT Id, Product_Group__c, Business_Unit__c FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
        
        System.assertNotEquals(null, createdOpp, 'Opportunity should still be created');
        System.assertEquals(null, createdOpp.Product_Group__c, 'Product Group should be null when Business Unit is null');
        System.assertEquals(null, createdOpp.Business_Unit__c, 'Business Unit should be null when not specified');
    }
}