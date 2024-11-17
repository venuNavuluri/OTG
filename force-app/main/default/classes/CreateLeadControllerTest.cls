@isTest
private class CreateLeadControllerTest {
    
    @isTest
    static void testCreateLead() {
        // Create a test Campaign Id
        
        Default_Account_Owner_Settings__c setting = new Default_Account_Owner_Settings__c();
        setting.SetupOwnerId=UserInfo.getOrganizationId();
        setting.Name = 'EMEA Default Owner ID';
        setting.EMEA_Default_Owner_ID__c     = '005Si0000004LInIAM';
        insert setting;
        Campaign testCampaign = new Campaign(Name = 'Test Campaign');
        insert testCampaign;
        
        Account acc = new Account();
        acc.Name = 'Test Account';
        acc.Customer_Status__c = 'Prospect';
        
        insert acc;
        
        // Create a test Contact
        Contact testContact = new Contact();
        testContact.LastName = 'Test';
        testContact.MobilePhone = '01234567890';
        testContact.AccountId = acc.Id;
        testContact.LastName = 'Contact';
        testContact.FirstName = 'Test';
        testContact.Email = 'test123123@example.com';
        
        insert testContact;
        
        
        Group testGroup = new Group(Name = 'TestGroup', Type = 'Queue', DeveloperName = 'MarketingCampaignTest');
        insert testGroup;
        
        // Use an existing Lead or create a unique email address
        //Lead existingLead = [SELECT Id, Email FROM Lead LIMIT 1];
        
        Test.setCurrentPageReference(new PageReference('/apex/CreateLeadVFPage')); // Change YourPageName to the actual page name
        
        // Set up parameters for the current page
        ApexPages.currentPage().getParameters().put('email', 'test123123@example.com');
        ApexPages.currentPage().getParameters().put('campaignId', testCampaign.Id); // Provide a valid Campaign Id
        
        // Call the method to test
        CreateLeadController controller = new CreateLeadController();
        Test.startTest();
        controller.createLead();
        Test.stopTest();
        
        // Verify that a lead is created
        List<Lead> leads = [SELECT Id FROM Lead WHERE Email = 'test123123@example.com'];
        System.assertEquals(1, leads.size(), 'A lead should have been created');
        
        // Add more assertions if needed
    }
}