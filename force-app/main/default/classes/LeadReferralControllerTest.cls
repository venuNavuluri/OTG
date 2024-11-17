@IsTest
public class LeadReferralControllerTest {

@IsTest
    public static void testUrlDomains(){
        String url1 = LeadReferralController.getDomainFromUrl('www.example.com');
        String url2 = LeadReferralController.getDomainFromUrl('https://www.example.com');
        String url3 = LeadReferralController.getDomainFromUrl('www.example.example2.com');
        Assert.areEqual('example.com', url1, 'Expected domain returned'); 
        Assert.areEqual('example.com', url2, 'Expected domain returned'); 
        Assert.areEqual('example2.com', url3, 'Expected domain returned'); 
    }  
	
@IsTest
    public static void testEmailSpamLead(){
        LeadReferralController.emailRules = new List<String> {'emailspam@example.com'};
		String formData = '{"firstName":"FistnameTestOne","lastName":"LastName","email":"emailspam@example.com","phone":"07777777777","existingCustomer":"Yes","numberOfEmployees":"50-200","companyName":"Unit Test","products":["Learning & Assessment","Fleet Management System (TM Master)"],"website":"https://www.unitetst.co.uk","customerbackground":"Ut quo veritatis ius","formType":"DemoRequest","message":"Quis qui ut sed nequ"}'; //,"E-learning Course Certification"
        LeadReferralController.validateLead(formData);
        Lead l = [SELECT Reason_For_Closing__c,Status FROM Lead WHERE Email = 'emailspam@example.com'];
        
        Assert.areEqual('Lost/Closed', l.Status, 'Lead Is Closed'); 
        Assert.areEqual('Spam', l.Reason_For_Closing__c, 'Lead Marked As Spam');          
    }
    
@IsTest
    public static void testDomainSpamLead(){
        LeadReferralController.domainRules = new List<String> {'unittest.com'};
		String formData = '{"firstName":"Fistname","lastName":"LastName","email":"emailSpam@example.com","phone":"07777777777","existingCustomer":"Yes","numberOfEmployees":"50-200","companyName":"Unit Test","products":["Learning & Assessment","Fleet Management System (TM Master)"],"website":"www.unittest.com","customerbackground":"Ut quo veritatis ius","formType":"DemoRequest","message":"Quis qui ut sed nequ"}';  //,"E-learning Course Certification"
        LeadReferralController.validateLead(formData);
        Lead l = [SELECT Reason_For_Closing__c,Status FROM Lead WHERE Website = 'www.unittest.com'];
        
        Assert.areEqual('Lost/Closed', l.Status, 'Lead Is Closed'); 
        Assert.areEqual('Spam', l.Reason_For_Closing__c, 'Lead Marked As Spam');          
    }

@IsTest
    public static void testKeywordSpamLead(){
        LeadReferralController.keywordRules = new List<String> {'keyword','spam'};
		String formData = '{"firstName":"Fistname","lastName":"LastName","email":"emailSpam@example.com","phone":"07777777777","existingCustomer":"Yes","numberOfEmployees":"50-200","companyName":"Unit Test","products":["Learning & Assessment","Fleet Management System (TM Master)"],"website":"www.unittest.com","customerbackground":"Ut quo veritatis ius","formType":"DemoRequest","message":"keyword spam"}';  //,"E-learning Course Certification"
        LeadReferralController.validateLead(formData);
        Lead l = [SELECT Reason_For_Closing__c,Status FROM Lead WHERE Website = 'www.unittest.com'];
        
        Assert.areEqual('Lost/Closed', l.Status, 'Lead Is Closed'); 
        Assert.areEqual('Spam', l.Reason_For_Closing__c, 'Lead Marked As Spam');          
    }
 
@IsTest
    public static void testValidLead(){
        LeadReferralController.keywordRules = new List<String> {'keyword spam'};
		LeadReferralController.domainRules = new List<String> {'spaunittest.com'};
		LeadReferralController.emailRules = new List<String> {'example@example.com'};
                    
		String formData = '{"firstName":"Fistname","lastName":"LastName","email":"emailSpam@unittest.com","phone":"07777777777","existingCustomer":"Yes","numberOfEmployees":"50-200","companyName":"Unit Test","products":["Learning & Assessment","Fleet Management System (TM Master)"],"website":"www.unittest111.com","customerbackground":"Ut quo veritatis ius","formType":"DemoRequest","message":"Test Message"}'; //,"E-learning Course Certification"
        LeadReferralController.validateLead(formData);
        Lead l = [SELECT Reason_For_Closing__c,Status FROM Lead WHERE Website = 'www.unittest111.com'];
        
        Assert.areEqual('New', l.Status, 'Lead is New'); 
        Assert.areEqual(null, l.Reason_For_Closing__c, 'Lead not marked as Lead Marked As Spam');          
    }
@IsTest
    public static void testCustomerTypes(){
        String types = LeadReferralController.getCustomerTypes();
		List<String> stringList = (List<String>)JSON.deserialize(types, List<String>.class);
        Assert.areNotEqual(0, stringList.size(), 'Types Returned'); 
    }    
    
}