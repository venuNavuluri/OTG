public class LeadReferralController {
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
            } else  if ((String)leadData.get('formType') == 'LeadWebPageOrigin'){
                SalesType = 'Lead Web Page Origin';
            }
        } 
        
        String queueId = getWebFormQueueId();
 
        Lead l = new Lead(
            OwnerId = queueId,
            Status = 'New',
            LeadSource ='LR-One Ocean',
            FirstName = (String)leadData.get('firstName'),
            LastName = (String)leadData.get('lastName'),
            Email = (String)leadData.get('email'),
            Company = (String)leadData.get('companyName'),
            //Customer_Type__c = (String)leadData.get('companyType'),
            Is_this_an_existing_customer_of_LR_or_LR__c = (String)leadData.get('existingCustomer'),
            Title = (String)leadData.get('jobTitle'),
            Description = (String)leadData.get('message'),
            Phone = (String)leadData.get('phone'),
            Website = (String)leadData.get('website'),
            Account_Salesforce_URL__c = (String)leadData.get('AccountURL'),
            Sales_Type__c = SalesType,
            Products__c = String.join(products, ';'),
            
            Sales_Person_Email__c = (String)leadData.get('salesPersonEmail'),
            Sales_Person_Full_Name__c = (String)leadData.get('salesPersonName'),
            Customer_background__c = (String)leadData.get('customerbackground'),
            Vessel_Name__c = (String)leadData.get('vesselDetails')
            
        );
        system.debug('lead Details ---' + l);
        
        Boolean isSpam = LeadReferralController.isSpam(l);
        
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
    private static Boolean checkForKeywords(String input, Set<String> keywords) {
    if (String.isEmpty(input)) {
        return false;
    }

    for (String word : input.split(' ')) {
        if (keywords.contains(word.toLowerCase())) {
            return true;
        }
    }

    return false;
}
    
    public static Boolean isSpam(Lead l){
        Boolean isSpam = false;
        Boolean blockedDomain = isDomainSpam(l.Email.toLowerCase(),l.Website.toLowerCase());
        Boolean blockedEmail = isEmailSpam(l.Email, l.Sales_Person_Email__c);
        Boolean blockedKeyworlds = isKeywordSpam(l.Description, l.Customer_background__c);
        
        if (blockedDomain || blockedEmail || blockedKeyworlds){
            isSpam = true;
        }
        
        return isSpam;
    }
    
    public static Boolean isEmailSpam(String emailAddress, String salesPersonEmail){
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
    
    private static Boolean isKeywordSpam(String message, String customerBackground) {
    if (keywordRules.isEmpty() && spamValidation.containsKey('Keyword')) {
        keywordRules = spamValidation.get('Keyword');
    }

    Set<String> keywordSet = new Set<String>();
    for (String rule : keywordRules) {
        keywordSet.add(rule.toLowerCase());
    }

    // Add null checks for message and customerBackground
    if (!String.isEmpty(message) && checkForKeywords(message, keywordSet)) {
        return true;
    }

    if (!String.isEmpty(customerBackground) && checkForKeywords(customerBackground, keywordSet)) {
        return true;
    }

    return false;
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
        List<String> IsLRcustomer = new List<String>(); 
        SObjectType objectType = Schema.getGlobalDescribe().get('Lead');
        SObjectField objectField = objectType.getDescribe().fields.getMap().get('Is_this_an_existing_customer_of_LR_or_LR__c');
        
        if (objectField.getDescribe().isAccessible()) {
            Schema.DescribeFieldResult fieldDescription = objectField.getDescribe();
            if (fieldDescription.getType() == Schema.DisplayType.Picklist) {
                List<Schema.PicklistEntry> picklistValues = fieldDescription.getPicklistValues();
                for (Schema.PicklistEntry picklistEntry : picklistValues) {
                    IsLRcustomer.add(picklistEntry.getValue());
                }
            }
        }
        return JSON.serialize(IsLRcustomer);
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