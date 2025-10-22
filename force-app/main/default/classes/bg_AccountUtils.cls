public class bg_AccountUtils
{
    public static String b2bRTId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('B2B Account').getRecordTypeId();
    public static String replicaRTId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Replica Invoice Account').getRecordTypeId();
    
    private static Pattern emailListPattern;
    
    public static final Set<String> ACC_EMAIL_FIELDS = new Set<String>{'Invoice_Emails__c', 'Statement_of_Account_Email__c', 'Remittance_Advice_Email__c'};
        
        public static final Integer HIERARCHY_RECURSION_LIMIT = 5;
    
    public static Integer hierarchyRecursionCount = 0;
    
    public static void AssignSalesPersonOwner(List<Account> accs)
    {
        Default_Account_Owner_Settings__c defaultSettings = Default_Account_Owner_Settings__c.getInstance();
        
        Set<Id> ownerIds = new Set<Id>();
        
        for (Account acc : accs)
        {
            ownerIds.add(acc.OwnerId);
            
        }
        
        Map<Id, User> usersMap = new Map<Id, User>([SELECT Id, UserRole.Name, UserRole.DeveloperName FROM User WHERE Id IN :ownerIds]);
        
        Map<Id, List<Account>> accountsByOwnerId = new Map<Id, List<Account>>();
        
        for (Account acc : accs)
        {
            if (accountsByOwnerId.get(acc.OwnerId) == null)
            {
                accountsByOwnerId.put(acc.OwnerId, new List<Account>());
                
            }
            accountsByOwnerId.get(acc.OwnerId).add(acc);
            
        }
        
        Map<String, List<Account>> accountsToReassignByRegion = new Map<String, List<Account>>();
        
        bg_UserUtils.PopulateRoles();
        for(Id userId : accountsByOwnerId.keySet())
        {
            User u = usersMap.get(userId);
            Boolean isSalesPerson = bg_UserUtils.IsSalesPerson(u.UserRole.Name);
            
            if (!isSalesPerson)
            {
                for (Account acc : accountsByOwnerId.get(userId))
                {
                    String salesRegion = acc.Sales_Region__c;
                    if (accountsToReassignByRegion.get(salesRegion) == null)
                    {
                        accountsToReassignByRegion.put(salesRegion, new List<Account>());
                    }
                    
                    accountsToReassignByRegion.get(salesRegion).add(acc);
                }
            }
        }
        
        Map<String, Id> defaultOwnerByRegion = new Map<String, Id>();
        defaultOwnerByRegion.put('Americas', defaultSettings.Americas_Default_Owner_ID__c);
        defaultOwnerByRegion.put('APAC', defaultSettings.APAC_Default_Owner_ID__c);
        defaultOwnerByRegion.put('EMEA', defaultSettings.EMEA_Default_Owner_ID__c);
        
        for(String region : accountsToReassignByRegion.keySet())
        {
            Id defaultOwnerId = defaultOwnerByRegion.get(region);
            if (defaultOwnerId != null)
            {
                for (Account acc : accountsToReassignByRegion.get(region))
                {
                    acc.OwnerId = defaultOwnerId;
                }
            }
        }
    }
    
    public static void ValidateAccEmailFields(List<Account> accs)
    {
        for (Account acc : accs)
        {
            for (String fieldName : ACC_EMAIL_FIELDS)
            {
                String fieldValue = (String) acc.get(fieldName);
                if (fieldValue != null)
                {
                    fieldValue = fieldValue.trim();
                }
                
                acc.put(fieldName, fieldValue);
                if (!IsValidEmailList(fieldValue))
                {
                    acc.addError(fieldName, 'Please enter a semi colon separated list of emails with no spaces.');
                }
            }
        }
    }
    
    public static Boolean IsValidEmailList(String emailListStr)
    {
        if (emailListStr == null)
        {
            return true;
        }
        
        // semi colon separated list of emails
        if (emailListPattern == null)
        {
            emailListPattern = Pattern.compile('^([\\w+\\-.%\']+@[\\w\\-.]+\\.[A-Za-z]{2,4}(?:;|$))+');
        }
        Matcher emailListMatcher = emailListPattern.matcher(emailListStr);
        
        return emailListMatcher.matches();
    }
    
    public static void BlockMultipleReplicaAccounts(List<Account> accounts)
    {
        
        Set<Id> b2bAccIds = new Set<Id>();
        for(Account acc : accounts)
        {
            b2bAccIds.add(acc.B2B_Account__c);
        }
        
        List<Account> replicas = [SELECT Id, B2B_Account__c FROM Account WHERE B2B_Account__c IN :b2bAccIds AND RecordTypeId = :replicaRTId];
        Map<Id, List<Account>> replicasByIdB2BId = new Map<Id, List<Account>>();
        for (Account acc : replicas)
        {
            if (acc.B2B_Account__c != null && replicasByIdB2BId.get(acc.B2B_Account__c) == null)
            {
                replicasByIdB2BId.put(acc.B2B_Account__c, new List<Account>{acc});
            }
            else
            {
                replicasByIdB2BId.get(acc.B2B_Account__c).add(acc);
            }
        }
        
        for (Account acc : accounts)
        {
            List<Account> existingReplicas = replicasByIdB2BId.get(acc.B2B_Account__c);
            if (existingReplicas != null && existingReplicas.size() > 0 )
            {
                for (Account replica : existingReplicas)
                {
                    if (replica.Id != acc.Id)
                    {
                        acc.addError('A replica account already exists for this B2B account.');
                    }
                }
            }
        }
    }
    
    public static void RecalculateReplicas(List<Account> accs)
    {
        Set<Id> b2bAccountIds = new Set<Id>();
        for (Account acc : accs)
        {
            b2bAccountIds.add(acc.B2B_Account__c);
        }
        
        List<Account> b2bAccounts = [SELECT Id, Validation_Toggle__c, (SELECT Id, RecordTypeId FROM Invoice_Accounts__r) FROM Account WHERE Id IN :b2bAccountIds];
        Map<Id, Boolean> validationToggleByB2BId = new Map<Id, Boolean>();
        Map<Id, Boolean> replicaCreatedByB2BId = new Map<Id, Boolean>();
        
        for (Account b2bAcc : b2bAccounts)
        {
            Boolean replicaCreated = false;
            for (Account invAcc : b2bAcc.Invoice_Accounts__r)
            {
                if (invAcc.RecordTypeId == replicaRTId)
                {
                    replicaCreated = true;
                }
            }
            
            replicaCreatedByB2BId.put(b2bAcc.Id, replicaCreated);
            validationToggleByB2BId.put(b2bAcc.Id, b2bAcc.Validation_Toggle__c);
        }
        
        List<Account> b2bAccountsToUpdate = new List<Account>();
        
        for (Id b2bAccId : replicaCreatedByB2BId.keySet())
        {
            b2bAccountsToUpdate.add(new Account(Id = b2bAccId, Validation_Toggle__c = !validationToggleByB2BId.get(b2bAccId), Replica_Created__c = replicaCreatedByB2BId.get(b2bAccId)));
        }
        
        update b2bAccountsToUpdate;
    }
    
    public static void BlockReplicaToInvoiceRTChange(List<Account> accs)
    {
        for (Account acc : accs)
        {
            acc.addError('You cannot change the record type of a Replica Invoice account.');
        }
    }
    
    public static void PopulateHierarchyFieldsFromUltimateParent(List<Account> accs)
    {
        if(hierarchyRecursionCount >= HIERARCHY_RECURSION_LIMIT)
        {
            return;
        }
        
        Set<Id> ultimateAccountIds = new Set<Id>();
        for (Account acc : accs)
        {
            ultimateAccountIds.add(acc.Id);
        }
        List<Account> ultimateAccounts = [SELECT Id, ParentId, Ultimate_Parent_Email__c, 
                                          Ultimate_Parent_Owner__c, Ultimate_Parent_Owner_Id__c, 
                                          Ultimate_Parent_Id__c, Ultimate_Parent_Name__c, 
                                          Ultimate_Parent_Account_Segmentation__c, Ultimate_Parent_Account_Number__c, Ultimate_Parent_Account_Sub_AOV__c, (SELECT Id FROM ChildAccounts) 
                                          FROM Account 
                                          WHERE Id IN :ultimateAccountIds AND RecordTypeId = :b2bRTId];
        hierarchyRecursionCount++;
        List<Account> accsToUpdate = new List<Account>();
        
        for (Account acc : ultimateAccounts)
        {
            for (Account childAccount : acc.ChildAccounts)
            {
                accsToUpdate.add(new Account(Id = childAccount.Id, Ultimate_Parent_Email__c = acc.Ultimate_Parent_Email__c,
                                             Ultimate_Parent_Owner__c = acc.Ultimate_Parent_Owner__c, Ultimate_Parent_Owner_Id__c = acc.Ultimate_Parent_Owner_Id__c,
                                             Ultimate_Parent_Id__c = acc.Ultimate_Parent_Id__c, Ultimate_Parent_Name__c = acc.Ultimate_Parent_Name__c, 
                                             Ultimate_Parent_Account_Segmentation__c = acc.Ultimate_Parent_Account_Segmentation__c,
                                             Ultimate_Parent_Account_Number__c = acc.Ultimate_Parent_Account_Number__c,
                                             Ultimate_Parent_Account_Sub_AOV__c = acc.Ultimate_Parent_Account_Sub_AOV__c));
            }
        }
        
        if (!accsToUpdate.isEmpty())
        {
            update accsToUpdate;
        }
    }
    
    public static void PopulateHierarchyFields(List<Account> accs)
    {
        Set<Id> parentAccountIds = new Set<Id>();
        Set<Id> ownerIds = new Set<Id>();
        for (Account acc : accs)
        {
            if (acc.ParentId != null)
            {
                parentAccountIds.add(acc.ParentId);
            }
            ownerIds.add(acc.OwnerId);
        }
        
        
        Map<Id, Account> parentAccountsById = new Map<Id, Account>([SELECT Id, Ultimate_Parent_Email__c, Ultimate_Parent_Owner__c, 
                                                                    Ultimate_Parent_Owner_Id__c, Ultimate_Parent_Id__c, 
                                                                    Ultimate_Parent_Name__c, Ultimate_Parent_Account_Segmentation__c,
                                                                    Ultimate_Parent_Account_Number__c, Ultimate_Parent_Account_Sub_AOV__c
                                                                    FROM Account WHERE Id IN :parentAccountIds AND RecordTypeId = :b2bRTId]);
        Map<Id, User> ownersById = new Map<Id, User>([SELECT Id, Email, FirstName, LastName FROM User WHERE Id IN :ownerIds]);
        
        for (Account acc : accs)
        {
            if(acc.ParentId != null && parentAccountsById.containsKey(acc.ParentId))
            {
                Account parentAccount = parentAccountsById.get(acc.ParentId);
                
                acc.Ultimate_Parent_Email__c = parentAccount.Ultimate_Parent_Email__c;
                acc.Ultimate_Parent_Owner__c = parentAccount.Ultimate_Parent_Owner__c;
                acc.Ultimate_Parent_Owner_Id__c = parentAccount.Ultimate_Parent_Owner_Id__c;
                acc.Ultimate_Parent_Id__c = parentAccount.Ultimate_Parent_Id__c;
                acc.Ultimate_Parent_Name__c = parentAccount.Ultimate_Parent_Name__c;
                acc.Ultimate_Parent_Account_Segmentation__c = parentAccount.Ultimate_Parent_Account_Segmentation__c;
                acc.Ultimate_Parent_Account_Number__c = parentAccount.Ultimate_Parent_Account_Number__c;
                acc.Ultimate_Parent_Account_Sub_AOV__c = parentAccount.Ultimate_Parent_Account_Sub_AOV__c;
                
            }
            else
            {
                User accountOwner = ownersById.get(acc.OwnerId);
                acc.Ultimate_Parent_Email__c = accountOwner.Email;
                acc.Ultimate_Parent_Owner__c = accountOwner.FirstName + ' ' + accountOwner.LastName;
                acc.Ultimate_Parent_Owner_Id__c = accountOwner.Id;
                acc.Ultimate_Parent_Id__c = acc.Id;
                acc.Ultimate_Parent_Name__c = acc.Name;
                acc.Ultimate_Parent_Account_Segmentation__c = acc.Account_Segmentation__c;
                acc.Ultimate_Parent_Account_Number__c = acc.Account_ID__c;
                acc.Ultimate_Parent_Account_Sub_AOV__c = acc.Subscription_Annual_Order_Value__c;
            }
        }
    }
    
    public static void PopulateUltimateParentIdField(List<Account> accs)
    {
        List<Account> accsToUpdate = new List<Account>();
        
        for (Account acc : accs)
        {
            if (acc.ParentId == null && acc.RecordTypeId == b2bRTId)
            {
                accsToUpdate.add(new Account(Id = acc.Id, Ultimate_Parent_Id__c = acc.Id));
            }
        }
        
        if (!accsToUpdate.isEmpty())
        {
            update accsToUpdate;
        }
    }
    public static void updateNonApprovedQuotesForAccounts(List<Account> accounts) {
        
        try{
            Map<String, String> paymentTermMapping = new Map<String, String>{
                'Due immediately' => 'Due on receipt',
                    '30 days from invoice date' => 'Net 30',
                    '45 days from invoice date' => 'Net 45',
                    '60 days from invoice date' => 'Net 60',
                    '90 days from invoice date' => 'Net 90'
                    };
                        
                        List<SBQQ__Quote__c> quotesToUpdate = [
                            SELECT Id, SBQQ__PaymentTerms__c, SBQQ__Account__r.Customer_Payment_Terms__c
                            FROM SBQQ__Quote__c
                            WHERE SBQQ__Account__c IN :accounts
                            AND SBQQ__Status__c IN ('Draft', 'In Review')
                        ];
            
            for (SBQQ__Quote__c quote : quotesToUpdate) {
                if (quote.SBQQ__Account__r.Customer_Payment_Terms__c != null &&
                    paymentTermMapping.containsKey(quote.SBQQ__Account__r.Customer_Payment_Terms__c)) {
                        
                        String newTerms = paymentTermMapping.get(quote.SBQQ__Account__r.Customer_Payment_Terms__c);
                        
                        if (quote.SBQQ__PaymentTerms__c != newTerms) {
                            quote.SBQQ__PaymentTerms__c = newTerms;
                        } else {
                            
                        }
                    }
            }
            if (!quotesToUpdate.isEmpty()) {
                update quotesToUpdate;
            }
        } catch(Exception ex) {
            System.debug('Error updating the Account Payment Terms: ' + ex.getMessage());
        }
    }
    
    public static void createProductSolutions(List<Account> accounts){
        try{
            List<String> BUSINESS_UNITS = new List<String>{
                'Voyage Performance & Optimization',
                    'Voyage Management',
                    'HCM Crew',
                    'HCM Learning, Assessment and Competency',
                    'Technical Ship Management',
                    'Governance, Risk & Compliance',
                    'Cloud Fleet Manager',
                    'API'
                    };
                        
                        List<Product_Solutions__c> productSolutionsToInsert = new  List<Product_Solutions__c>();
            
            for(Account acc : accounts){
                for(string businessUnit : BUSINESS_UNITS){
                    Product_Solutions__c ps = new Product_Solutions__c(
                    	Account_ID__c = acc.id,
                        Product_Solution__c = businessUnit,
                        Product_Area_Status__c = 'Prospect'
                    );
                   productSolutionsToInsert.add(ps); 
                }
                
            }
            if(!productSolutionsToInsert.isEmpty()){
                insert productSolutionsToInsert;
            }
            system.debug('Product Solutions Created ===' + productSolutionsToInsert );
            
        }
        catch(Exception ex) {
            System.debug('Error creating Product Solutions: ' + ex.getMessage());
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
        }
        
    }
}