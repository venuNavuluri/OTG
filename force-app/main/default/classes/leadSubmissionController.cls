/**
 * @description       : 
 * @author            : Jasdeep Bahra
 * @group             : 
 * @last modified on  : 12-14-2023
 * @last modified by  : Jasdeep Bahra
**/
public with sharing class leadSubmissionController {
    public static Map<String, List<String>> spamValidation = getValidation();
    public static List<String> emailRules = new List<String>();
    public static List<String> domainRules = new List<String>();
    public static List<String> keywordRules = new List<String>();
 
     
     @AuraEnabled
     public static void validateLead(String formData){
         List<Lead> newLeads = new List<Lead>();
         Map<String,Object> leadData = (Map<String,Object>)JSON.deserializeUntyped(formData);        
         List<Object> products = (List<Object>)leadData.get('products');
         String SalesType = 'Subscription';
         
         if ((String)leadData.get('formType') != ''){
             if ((String)leadData.get('formType') == 'ContactSales'){
                 SalesType = 'Contact Sales';
             } else  if ((String)leadData.get('formType') == 'RequestDemo'){
                 SalesType = 'Request Demo';
             }
         } 
                
         String queueId = getWebFormQueueId();

         Lead l = new Lead(
             OwnerId = queueId,
             Status = 'New',
             LeadSource ='Website Enquiry',
             FirstName = (String)leadData.get('firstName'),
             LastName = (String)leadData.get('lastName'),
             Email = (String)leadData.get('email'),
             Company = (String)leadData.get('companyName'),
             Customer_Type__c = (String)leadData.get('companyType'),
             Title = (String)leadData.get('jobTitle'),
             Description = (String)leadData.get('message'),
             Phone = (String)leadData.get('phone'),
             Website = (String)leadData.get('website'),
             Where_did_you_hear_about_us__c = (String)leadData.get('hearAboutUs'),
             Sales_Type__c = SalesType,
             Products__c = String.join(products, ';')
         );
         
         Boolean isSpam = leadSubmissionController.isSpam(l);
        
         if (isSpam == true){
             l.Reason_For_Closing__c = 'Spam';
             l.Status = 'Lost/Closed'; 
         }
         
         newLeads.add(l);
   
         if (newLeads.size()>0){
             submitLeads(newLeads);
         }
     }
     
     public static void submitLeads (List<Lead> newLeads){
         try {
             insert newLeads;
         } catch (DMLException ex){
             System.debug('Error'+ex);
         }
     }
     
     public static Boolean isSpam(Lead l){
         Boolean isSpam = false;
         Boolean blockedDomain = isDomainSpam(l.Email.toLowerCase(),l.Website.toLowerCase());
         Boolean blockedEmail = isEmailSpam(l.Email);
         Boolean blockedKeyworlds = isKeywordSpam(l.Description, l.Where_did_you_hear_about_us__c);

         if (blockedDomain || blockedEmail || blockedKeyworlds){
             isSpam = true;
         }
        
         return isSpam;
     }
     
     public static Boolean isEmailSpam(String emailAddress){
         Boolean spamEmail = false;
         if (emailRules.isEmpty() && spamValidation.size() > 0 && spamValidation.get('Email') != null){
             emailRules = spamValidation.get('Email');
         } 
         if (emailRules.size()>0){
         	 Set<String> emailStrings = new Set<String>(emailRules);
             Set<String> emailStringsToLowerCase = new Set<String>();
             
             for (String email : emailStrings){
                 emailStringsToLowerCase.add(email.toLowerCase());
             } 
             
             if (emailStringsToLowerCase.contains(emailAddress.toLowerCase())){
                 spamEmail = true;
             }
         }
         return spamEmail;
     }
     
     public static Boolean isKeywordSpam(String message,String hearAboutUs){
         Boolean keywordSpam = false;
		 if (keywordRules.isEmpty() && spamValidation.size() > 0 && spamValidation.size()!=null){
             keywordRules = spamValidation.get('Keyword');
         }
         
         if (keywordRules.size()>0){
             //convert to lowercase
             Set<String> keywordsLowerCase = new Set<String>();
			 Set<String> keyWordStrings = new Set<String>(keywordRules);

             for (String str :keyWordStrings){
                 keywordsLowerCase.add(str.toLowerCase());   
             }
            
             List<String> splitMessage = message.split(' ');
             for (String word : splitMessage){
                 if (keywordsLowerCase.contains(word.toLowerCase())){
                    keywordSpam = true;
                 }
             }

             List<String> aboutUsSplit = hearAboutUs.split(' ');
             for (String word : aboutUsSplit){
                 if (keywordsLowerCase.contains(word.toLowerCase())){
                    keywordSpam = true;
                 }
             }
         }
         return keywordSpam; 
     }
     
     public static Boolean isDomainSpam(String emailAddress,String Website){
         Boolean spamDomaim = false;
         If (domainRules.isEmpty() && spamValidation.size() > 0 && spamValidation.get('Domain') != null){
             domainRules = spamValidation.get('Domain');  
         }
         if (domainRules.size() > 0){
             Set<String> sStrings = new Set<String>(domainRules);
             emailAddress = emailAddress.split('@')[1].toLowerCase();
         
             String domain = getDomainFromUrl(Website);
              System.debug(domain);
             if ((domain != null && sStrings.contains(domain.toLowerCase())) || sStrings.contains(emailAddress.toLowerCase())){
                 spamDomaim = true;
             }
         }
         return spamDomaim;
     }
     
     public static Map<String, List<String>> getValidation(){
         List<Spam_Lead_Submission_Rules__mdt> rulesList = [SELECT Id, Type__c, Value__c FROM Spam_Lead_Submission_Rules__mdt];
         Map<String, List<String>> typeValueMap = new Map<String, List<String>>();
 
         for (Spam_Lead_Submission_Rules__mdt rule : rulesList) {
             String type = rule.Type__c;
             String value = rule.Value__c;
             
             if (!typeValueMap.containsKey(type)) {
                 typeValueMap.put(type, new List<String>{value});
             } else {
                 typeValueMap.get(type).add(value.toLowerCase());
             }
         }
         return typeValueMap;        
     }
     
     @AuraEnabled(Cacheable=true)
     public static String getCustomerTypes(){
         List<String> customerTypes = new List<String>(); 
         SObjectType objectType = Schema.getGlobalDescribe().get('Lead');
         SObjectField objectField = objectType.getDescribe().fields.getMap().get('Customer_Type__c');
 
         if (objectField.getDescribe().isAccessible()) {
             Schema.DescribeFieldResult fieldDescription = objectField.getDescribe();
             if (fieldDescription.getType() == Schema.DisplayType.Picklist) {
                 List<Schema.PicklistEntry> picklistValues = fieldDescription.getPicklistValues();
                 for (Schema.PicklistEntry picklistEntry : picklistValues) {
                     customerTypes.add(picklistEntry.getValue());
                 }
             }
         }
         return JSON.serialize(customerTypes);
     }  
     
     
    public static String getDomainFromUrl(String url) {
        String regex = '^(?:https?:\\/\\/)?(?:www\\.)?([^\\/]+)';

        Pattern pattern = Pattern.compile(regex);
        Matcher matcher = pattern.matcher(url);

        if (matcher.find()) {
            String fullDomain = matcher.group(1);
            String[] parts = fullDomain.split('\\.');
            if (parts.size() > 1) {
                return parts[parts.size() - 2] + '.' + parts[parts.size() - 1];
            } else {
                return fullDomain;
            }
        } else {
            return null;
        }
     }

    public static String getWebFormQueueId()
    {
        String queueId = [SELECT Id FROM Group where Name = 'WebForm' and Type = 'Queue'].Id;
        return queueId;
    }

 }