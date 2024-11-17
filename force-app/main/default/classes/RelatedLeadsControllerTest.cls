@IsTest
public class RelatedLeadsControllerTest {
    @testSetup
    static void setupTestData() {
        
        // Create a test Account and Contact
        Default_Account_Owner_Settings__c setting = new Default_Account_Owner_Settings__c();
        setting.SetupOwnerId=UserInfo.getOrganizationId();
        setting.Name = 'EMEA Default Owner ID';
        setting.EMEA_Default_Owner_ID__c     = '005Si0000004LInIAM';
        insert setting;
        
        Campaign testCampaign = new Campaign(Name = 'Test Campaign');
        insert testCampaign;
        
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        Contact testContact = new Contact(FirstName = 'John', LastName = 'Doe', AccountId = testAccount.Id);
        insert testContact;
        
        // Create a Lead that initially has a 'Working' status to comply with the validation rule
        Lead lead1 = new Lead(
            FirstName = 'Lead', 
            LastName = 'One', 
            Company = 'Test Company', 
            Status = 'Working', // Set to a status that complies with the validation rule
            Account__c = testAccount.Id
        );
        insert lead1;
        
        // Create a converted Lead with the appropriate status history
        Lead lead2 = new Lead(
            FirstName = 'Lead', 
            LastName = 'Two', 
            Company = 'Test Company', 
            Status = 'Working', // Initial status is 'Working' to comply with the validation rule
            Contact__c = testContact.Id
        );
        
        insert lead2;
        
        // Update the lead to simulate conversion, which requires setting IsConverted to TRUE
        lead2.Status = 'Qualified'; // Change status to simulate further progression
        update lead2;
    }
    
    @IsTest
    static void testGetRelatedLeadsWithAccountId() {
        // Retrieve the Account created in test setup
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        // Call the method to test
        List<Lead> resultLeads = RelatedLeadsController.getRelatedLeads(testAccount.Id);
        
        // Assert the results
        System.assertNotEquals(null, resultLeads, 'The result should not be null.');
        System.assertEquals(1, resultLeads.size(), 'There should be one related Lead with the Account lookup.');
        System.assertEquals(testAccount.Id, resultLeads[0].Account__c, 'The Lead should be related to the test Account.');
    }
    
    @IsTest
    static void testGetRelatedLeadsWithContactId() {
        // Retrieve the Contact created in test setup
        Contact testContact = [SELECT Id FROM Contact WHERE FirstName = 'John' AND LastName = 'Doe' LIMIT 1];
        
        // Call the method to test
        List<Lead> resultLeads = RelatedLeadsController.getRelatedLeads(testContact.Id);
        
        // Assert the results
        System.assertNotEquals(null, resultLeads, 'The result should not be null.');
        System.assertEquals(1, resultLeads.size(), 'There should be one related Lead with the Contact lookup.');
        System.assertEquals(testContact.Id, resultLeads[0].Contact__c, 'The Lead should be related to the test Contact.');
    }
    
    @IsTest
    static void testGetRelatedLeadsNoResults() {
        // Use an Id that doesn't have related Leads
        List<Lead> resultLeads = RelatedLeadsController.getRelatedLeads('001000000000000AAA'); // Assuming this is a dummy ID not present in the org
        
        // Assert that the result is an empty list
        System.assertEquals(0, resultLeads.size(), 'There should be no related Leads for a non-existent Account or Contact ID.');
    }
}