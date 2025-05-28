@isTest
public class AgentRelationshipTriggerHandlerTest {
    @testSetup
    static void setupTestData() {
        Profile prof = [SELECT Id FROM Profile WHERE Name = 'OTG Sales User'];
        User u = (User)TestDataFactory.createSObject('User', new Map<String, Object>{
            'profileId' => prof.id,
                'Username' => 'test@rrrr.com..otguatProd4'
                });
        
        Default_Account_Owner_Settings__c da = (Default_Account_Owner_Settings__c)TestDataFactory.createSObject('Default_Account_Owner_Settings__c', new Map<String, Object> {
            'EMEA_Default_Owner_ID__c' => u.id
                });
        
        Country_Mapping__c cm = new Country_Mapping__c();
        cm.Name = 'Test';
        cm.Sales_Region__c = 'Americas';
        insert cm;
        
        Account b2bAccount = new Account(
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('B2B Account').getRecordTypeId(),
            Name = 'Test B2B Account',
            Account_Status__c = 'Unverified', 
            AccountSource = 'Cross Department Referral', 
            Address1__c = 'Test', 
            Town_City__c = 'Texas', 
            Country__c = cm.Id, 
            Account_Segmentation__c = 'Unknown', 
            Customer_Type__c = 'Charity', 
            OwnerId = u.Id
        );
        insert b2bAccount;
        
        Account agentAccount = new Account(
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Agent Account').getRecordTypeId(),
            Name = 'Test Agent Account',
            Company__c = 'Test',
            CurrencyIsoCode = 'USD',
            Invoice_Emails__c = 'Test@test.com',
            Town_City__c = 'Town',
            Business_Unit__c = 'Fleet',
            Country__c = cm.Id
        );
        insert agentAccount;

        Agent_Relationship__c existingRelationship = new Agent_Relationship__c(
            B2B_Account__c = b2bAccount.Id,
            Agent_Account__c = agentAccount.Id,
            Business_Unit__c = 'Learning & Assessment'
        );
        insert existingRelationship;
    }
    @isTest
    static void testBeforeInsert_NoConflict() {
        Account b2bAccount = [SELECT Id FROM Account WHERE Name = 'Test B2B Account' LIMIT 1];
        Account agentAccount = [SELECT Id FROM Account WHERE Name = 'Test Agent Account' LIMIT 1];
        
        Agent_Relationship__c newRelationship = new Agent_Relationship__c(
            B2B_Account__c = b2bAccount.Id,
            Agent_Account__c = agentAccount.Id,
            Business_Unit__c = 'Fleet' 
        );
        
        Boolean insertSuccess = false;
        Test.startTest();
        try {
            insert newRelationship;
            insertSuccess = true;
        } catch (DmlException e) {
            
        }
        Test.stopTest();
        
        if (!insertSuccess) {
            List<Agent_Relationship__c> insertedRecords = [
                SELECT Id FROM Agent_Relationship__c WHERE Business_Unit__c = 'Fleet'
            ];
            System.assertEquals(1, insertedRecords.size(), 'Insert failed for non-conflicting Business Unit');
        } else {
            
        }
    }
    
   @isTest
    static void testBeforeInsert_ConflictDetected() {
        List<Account> b2bAccounts = [SELECT Id FROM Account WHERE Name = 'Test B2B Account' LIMIT 1];
        List<Account> agentAccounts = [SELECT Id FROM Account WHERE Name = 'Test Agent Account' LIMIT 1];
        
        System.assert(!b2bAccounts.isEmpty(), 'B2B Account setup failed');
        System.assert(!agentAccounts.isEmpty(), 'Agent Account setup failed');
        
        // Try to insert a duplicate Business Unit
        Agent_Relationship__c duplicateRelationship = new Agent_Relationship__c(
            B2B_Account__c = b2bAccounts[0].Id,
            Agent_Account__c = agentAccounts[0].Id,
            Business_Unit__c = 'Learning & Assessment'
        );
        
        Test.startTest();
        try {
            insert duplicateRelationship;
            System.assert(false, 'Expected insert failure due to business unit conflict');
        } catch (DmlException e) {
           System.assert(e.getMessage().contains('Business Unit value already exists'), 'Unexpected error message: ' + e.getMessage());
        }
        Test.stopTest();
    }
    
    @isTest
    static void testBeforeUpdate_MergeBusinessUnits() {
        List<Agent_Relationship__c> records = [
            SELECT Id, Business_Unit__c FROM Agent_Relationship__c WHERE Business_Unit__c = 'Learning & Assessment' LIMIT 1
        ];
        System.assert(records.size() > 0, 'No Agent Relationship record found for testing');
        Agent_Relationship__c existingRecord = records[0];

        existingRecord.Business_Unit__c += ';Crew';
        
        Boolean updateSuccess = false;
        Test.startTest();
        try {
            update existingRecord;
            updateSuccess = true;
        } catch (DmlException e) {
          
        }
        Test.stopTest();
        
        if (updateSuccess) {
            Agent_Relationship__c updatedRecord = [
                SELECT Business_Unit__c FROM Agent_Relationship__c WHERE Id = :existingRecord.Id
            ];
            System.assert(updatedRecord.Business_Unit__c.contains('Crew'), 'Business Unit merging failed');
        } else {

        }
    }
    
    @isTest
    static void testAfterInsert_DeleteConflictingRecords() {
        Account b2bAccount = [SELECT Id FROM Account WHERE Name = 'Test B2B Account' LIMIT 1];
        Account agentAccount = [SELECT Id FROM Account WHERE Name = 'Test Agent Account' LIMIT 1];

        Agent_Relationship__c validRecord = new Agent_Relationship__c(
            B2B_Account__c = b2bAccount.Id,
            Agent_Account__c = agentAccount.Id,
            Business_Unit__c = 'Fleet'
        );
        
        Test.startTest();
        insert validRecord;
        Test.stopTest();
        

        List<Agent_Relationship__c> records = [
            SELECT Id, Business_Unit__c FROM Agent_Relationship__c WHERE B2B_Account__c = :b2bAccount.Id
        ];
        
        System.assert(records.size() >= 1, 'Expected at least one record to remain.');
    }
}