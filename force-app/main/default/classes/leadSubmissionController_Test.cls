/**
 * @description       : 
 * @author            : Jasdeep Bahra
 * @group             : 
 * @last modified on  : 12-15-2023
 * @last modified by  : Jasdeep Bahra
**/
@IsTest
public class leadSubmissionController_Test {

@IsTest
    public static void testUrlDomains(){
        String url1 = leadSubmissionController.getDomainFromUrl('www.example.com');
        String url2 = leadSubmissionController.getDomainFromUrl('https://www.example.com');
        String url3 = leadSubmissionController.getDomainFromUrl('www.example.example2.com');
        Assert.areEqual('example.com', url1, 'Expected domain returned'); 
        Assert.areEqual('example.com', url2, 'Expected domain returned'); 
        Assert.areEqual('example2.com', url3, 'Expected domain returned'); 
    }  
	
@IsTest
    public static void testEmailSpamLead(){
        leadSubmissionController.emailRules = new List<String> {'emailspam@example.com'};
		String formData = '{"firstName":"FistnameTestOne","lastName":"LastName","email":"emailspam@example.com","jobTitle":"Developer","phone":"07777777777","companyType":"Content Provider / OEM","numberOfEmployees":"50-200","companyName":"Unit Test","products":["Learning & Assessment","Fleet Management System (TM Master)"],"website":"https://www.unitetst.co.uk","hearAboutUs":"Ut quo veritatis ius","formType":"DemoRequest","message":"Quis qui ut sed nequ"}'; //,"E-learning Course Certification"
        leadSubmissionController.validateLead(formData);
        Lead l = [SELECT Reason_For_Closing__c,Status FROM Lead WHERE Email = 'emailspam@example.com'];
        
        Assert.areEqual('Lost/Closed', l.Status, 'Lead Is Closed'); 
        Assert.areEqual('Spam', l.Reason_For_Closing__c, 'Lead Marked As Spam');          
    }
    
@IsTest
    public static void testDomainSpamLead(){
        leadSubmissionController.domainRules = new List<String> {'unittest.com'};
		String formData = '{"firstName":"Fistname","lastName":"LastName","email":"emailSpam@example.com","jobTitle":"Developer","phone":"07777777777","companyType":"Content Provider / OEM","numberOfEmployees":"50-200","companyName":"Unit Test","products":["Learning & Assessment","Fleet Management System (TM Master)"],"website":"www.unittest.com","hearAboutUs":"Ut quo veritatis ius","formType":"DemoRequest","message":"Quis qui ut sed nequ"}';  //,"E-learning Course Certification"
        leadSubmissionController.validateLead(formData);
        Lead l = [SELECT Reason_For_Closing__c,Status FROM Lead WHERE Website = 'www.unittest.com'];
        
        Assert.areEqual('Lost/Closed', l.Status, 'Lead Is Closed'); 
        Assert.areEqual('Spam', l.Reason_For_Closing__c, 'Lead Marked As Spam');          
    }

@IsTest
    public static void testKeywordSpamLead(){
        leadSubmissionController.keywordRules = new List<String> {'keyword','spam'};
		String formData = '{"firstName":"Fistname","lastName":"LastName","email":"emailSpam@example.com","jobTitle":"Developer","phone":"07777777777","companyType":"Content Provider / OEM","numberOfEmployees":"50-200","companyName":"Unit Test","products":["Learning & Assessment","Fleet Management System (TM Master)"],"website":"www.unittest.com","hearAboutUs":"Ut quo veritatis ius","formType":"DemoRequest","message":"keyword spam"}';  //,"E-learning Course Certification"
        leadSubmissionController.validateLead(formData);
        Lead l = [SELECT Reason_For_Closing__c,Status FROM Lead WHERE Website = 'www.unittest.com'];
        
        Assert.areEqual('Lost/Closed', l.Status, 'Lead Is Closed'); 
        Assert.areEqual('Spam', l.Reason_For_Closing__c, 'Lead Marked As Spam');          
    }
 
@IsTest
    public static void testValidLead(){
        leadSubmissionController.keywordRules = new List<String> {'keyword spam'};
		leadSubmissionController.domainRules = new List<String> {'spaunittest.com'};
		leadSubmissionController.emailRules = new List<String> {'example@example.com'};
                    
		String formData = '{"firstName":"Fistname","lastName":"LastName","email":"emailSpam@unittest.com","jobTitle":"Developer","phone":"07777777777","companyType":"Content Provider / OEM","numberOfEmployees":"50-200","companyName":"Unit Test","products":["Learning & Assessment","Fleet Management System (TM Master)"],"website":"www.unittest111.com","hearAboutUs":"Ut quo veritatis ius","formType":"DemoRequest","message":"Test Message"}'; //,"E-learning Course Certification"
        leadSubmissionController.validateLead(formData);
        Lead l = [SELECT Reason_For_Closing__c,Status FROM Lead WHERE Website = 'www.unittest111.com'];
        
        Assert.areEqual('New', l.Status, 'Lead is New'); 
        Assert.areEqual(null, l.Reason_For_Closing__c, 'Lead not marked as Lead Marked As Spam');          
    }
@IsTest
    public static void testCustomerTypes(){
        String types = leadSubmissionController.getCustomerTypes();
		List<String> stringList = (List<String>)JSON.deserialize(types, List<String>.class);
        Assert.areNotEqual(0, stringList.size(), 'Types Returned'); 
    }    
    
}