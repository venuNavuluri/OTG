@isTest
public class EmailComposerControllerTest {
    
    @TestSetup
    static void setupSetupObjects() {
        // Create email template
        EmailTemplate testTemplate = new EmailTemplate(
            Name = 'Support Email Template',
            DeveloperName = 'Support_Email_Template',
            TemplateType = 'text',
            Subject = 'Regarding your support request',
            Body = 'Dear {!Lead.FirstName}, Thank you for contacting support.',
            FolderId = UserInfo.getUserId(), // Required field, using user folder
            IsActive = true
        );
        insert testTemplate;
    }
    
    static void setupNonSetupObjects() {
        // Create test lead
        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Company = 'Test Company',
            Email = 'testlead@example.com',
            Status = 'Open',
            Products__c ='Fleet Management System (TM Master)',
            Description = 'Test Description'
        );
        insert testLead;
    }
    
    @isTest
    static void testGetSupportEmailTemplate() {
        Test.startTest();
        String templateId = EmailComposerController.getSupportEmailTemplate();
        Test.stopTest();
        
        System.assertNotEquals(null, templateId, 'Template ID should not be null');
    }
    
    @isTest
    static void testRenderEmailTemplate() {
        setupNonSetupObjects(); 
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        EmailTemplate testTemplate = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'Support_Email_Template' LIMIT 1];
        
        Test.startTest();
        EmailComposerController.EmailRenderResult result = 
            EmailComposerController.renderEmailTemplate(testTemplate.Id, testLead.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.subject, 'Subject should not be null');
        System.assertNotEquals(null, result.body, 'Body should not be null');
        System.assert(result.body.contains('Test'), 'Body should contain lead first name');
    }
    
    @isTest
    static void testRenderEmailTemplateFailure() {
        setupNonSetupObjects(); // Create leads in separate transaction
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        
        Boolean exceptionThrown = false;
        
        Test.startTest();
        try {
            EmailComposerController.EmailRenderResult result = 
                EmailComposerController.renderEmailTemplate('invalidId', testLead.Id);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Should throw exception for invalid template ID');
    }
    
    @isTest
    static void testSendEmailAndUpdateLead() {
        setupNonSetupObjects(); // Create leads in separate transaction
        Lead testLead = [SELECT Id, Status FROM Lead LIMIT 1];
        EmailTemplate testTemplate = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'Support_Email_Template' LIMIT 1];
        
        Test.startTest();
        EmailComposerController.sendEmailAndUpdateLead(
            testLead.Id,
            testTemplate.Id,
            'testlead@example.com',
            'support@company.com',
            'cc1@example.com;cc2@example.com',
            'bcc@example.com',
            'Test Subject',
            'Test Body'
        );
        Test.stopTest();
        
        // Verify lead was updated
        Lead updatedLead = [SELECT Id, Status, Reason_For_Closing__c, Reason_for_Closing_Comments__c 
                          FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals('Lost/Closed', updatedLead.Status, 'Lead status should be updated');
        System.assertEquals('Support Enquiry', updatedLead.Reason_For_Closing__c, 'Reason should be set');
        
        // Verify email was sent (checking Task creation since setSaveAsActivity=true)
        List<Task> emailTasks = [SELECT Id FROM Task WHERE WhoId = :testLead.Id];
        System.assert(!emailTasks.isEmpty(), 'Email activity should be created');
    }
    
    @isTest
    static void testSendEmailWithEmptyCCBCC() {
        setupNonSetupObjects(); 
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        EmailTemplate testTemplate = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'Support_Email_Template' LIMIT 1];
        
        Test.startTest();
        EmailComposerController.sendEmailAndUpdateLead(
            testLead.Id,
            testTemplate.Id,
            'testlead@example.com',
            'support@company.com',
            '', // empty CC
            '', // empty BCC
            'Test Subject',
            'Test Body'
        );
        Test.stopTest();
        
        System.assert(true, 'Should handle empty CC/BCC without errors');
    }
    
    @isTest
    static void testSendEmailFailure() {
        Boolean exceptionThrown = false;
        
        Test.startTest();
        try {
            EmailComposerController.sendEmailAndUpdateLead(
                'invalidId', 
                'invalidId', 
                'test@example.com',
                'support@company.com',
                '',
                '',
                'Test Subject',
                'Test Body'
            );
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Should throw exception for invalid parameters');
    }
   
    @isTest
    static void testGetOrgWideEmails() {
        User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        
        System.runAs(testUser) {
            Test.startTest();
            List<String> emailAddresses = EmailComposerController.getOrgWideEmails();
            Test.stopTest();
            
            System.assert(!emailAddresses.isEmpty(), 'Should return org-wide emails');
        }
    }
}