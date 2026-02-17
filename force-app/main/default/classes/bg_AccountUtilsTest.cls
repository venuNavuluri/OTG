@isTest
public class bg_AccountUtilsTest
{
    @isTest
    static void AccountDefaultOwnerTestSalesUser()
    {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        List<Sales_Person_Role_Mapping__mdt> roleMappings = [SELECT Id, MasterLabel, DeveloperName FROM Sales_Person_Role_Mapping__mdt];
        Set<String> mappedRoleNames = new Set<String>();
        for (Sales_Person_Role_Mapping__mdt mapping : roleMappings) {
            mappedRoleNames.add(mapping.MasterLabel);
        }
        List<UserRole> matchedRoles = [SELECT Id FROM UserRole WHERE Name IN :mappedRoleNames LIMIT 1];
        UserRole uRole = !matchedRoles.isEmpty() ? matchedRoles[0] : [SELECT Id FROM UserRole LIMIT 1];
        User testUser = new User(Username='bgotgtest@test.com', LastName='bg_AccountUtilsTest');
        testUser.Email = 'bgotgtest@test.com';
        testUser.Alias = 'bgotg';
        testUser.TimeZoneSidKey = 'Europe/London';
        testUser.LocaleSidKey = 'en_GB';
        testUser.EmailEncodingKey = 'UTF-8';
        testUser.ProfileId = p.Id;
        testUser.LanguageLocaleKey = 'en_US';
        testUser.UserRoleId = uRole.Id;
        insert testUser;
        
        User defaultUser = new User(Username='bgotgtestdefault@test.com', LastName='bg_AccountUtilsTest');
        defaultUser.Email = 'bgotgtest@test.com';
        defaultUser.Alias = 'bgotg';
        defaultUser.TimeZoneSidKey = 'Europe/London';
        defaultUser.LocaleSidKey = 'en_GB';
        defaultUser.EmailEncodingKey = 'UTF-8';
        defaultUser.ProfileId = p.Id;
        defaultUser.LanguageLocaleKey = 'en_US';
        defaultUser.UserRoleId = uRole.Id;
        insert defaultUser;
        
        System.runAs(testUser)
        {
            Default_Account_Owner_Settings__c defaultSettings = new Default_Account_Owner_Settings__c();
            defaultSettings.Americas_Default_Owner_ID__c = defaultUser.Id;
            defaultSettings.APAC_Default_Owner_ID__c = defaultUser.Id;
            defaultSettings.EMEA_Default_Owner_ID__c = defaultUser.Id;
            insert defaultSettings;
            
            Country_Mapping__c mapping = new Country_Mapping__c(Name = 'United Kingdom', Sales_Region__c = 'EMEA', Default_Account_Owner__c = defaultUser.Id);
            insert mapping;
            
            Account testAccount = new Account(Name = 'Test Account', Country__c = mapping.Id);
            Test.startTest();
            insert testAccount;
            Test.stopTest();
            
            Account testAccountResult = [SELECT Id, OwnerId FROM Account WHERE Id = :testAccount.Id LIMIT 1]; 
            //System.assertEquals(testUser.Id, testAccountResult.OwnerId, 'Owner should not have changed');
        }
    }
    
    @isTest
    static void AccountDefaultOwnerTestNonSalesUser()
    {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        List<Sales_Person_Role_Mapping__mdt> roleMappings = [SELECT Id, MasterLabel, DeveloperName FROM Sales_Person_Role_Mapping__mdt];
        Set<String> mappedRoleNames = new Set<String>();
        for (Sales_Person_Role_Mapping__mdt mapping : roleMappings) {
            mappedRoleNames.add(mapping.MasterLabel);
        }
        List<UserRole> matchedRoles = [SELECT Id FROM UserRole WHERE Name IN :mappedRoleNames LIMIT 1];
        UserRole uRole = !matchedRoles.isEmpty() ? matchedRoles[0] : [SELECT Id FROM UserRole LIMIT 1];
        User testUser = new User(Username='bgotgtest@test.com', LastName='bg_AccountUtilsTest');
        testUser.Email = 'bgotgtest@test.com';
        testUser.Alias = 'bgotg';
        testUser.TimeZoneSidKey = 'Europe/London';
        testUser.LocaleSidKey = 'en_GB';
        testUser.EmailEncodingKey = 'UTF-8';
        testUser.ProfileId = p.Id;
        testUser.LanguageLocaleKey = 'en_US';
        testUser.UserRoleId = null;
        insert testUser;
        
        User defaultUser = new User(Username='bgotgtestdefault@test.com', LastName='bg_AccountUtilsTest');
        defaultUser.Email = 'bgotgtest@test.com';
        defaultUser.Alias = 'bgotg';
        defaultUser.TimeZoneSidKey = 'Europe/London';
        defaultUser.LocaleSidKey = 'en_GB';
        defaultUser.EmailEncodingKey = 'UTF-8';
        defaultUser.ProfileId = p.Id;
        defaultUser.LanguageLocaleKey = 'en_US';
        defaultUser.UserRoleId = uRole.Id;
        insert defaultUser;
        
        System.runAs(testUser)
        {
            Default_Account_Owner_Settings__c defaultSettings = new Default_Account_Owner_Settings__c();
            defaultSettings.Americas_Default_Owner_ID__c = defaultUser.Id;
            defaultSettings.APAC_Default_Owner_ID__c = defaultUser.Id;
            defaultSettings.EMEA_Default_Owner_ID__c = defaultUser.Id;
            insert defaultSettings;
            
            Country_Mapping__c mapping = new Country_Mapping__c(Name = 'United Kingdom', Sales_Region__c = 'EMEA');
            insert mapping;
            
            Account testAccount = new Account(Name = 'Test Account', Country__c = mapping.Id);
            Test.startTest();
            insert testAccount;
            Test.stopTest();
            
            Account testAccountResult = [SELECT Id, OwnerId FROM Account WHERE Id = :testAccount.Id LIMIT 1]; 
            System.assertNotEquals(testUser.Id, testAccountResult.OwnerId, 'Owner should have changed');
            System.assertEquals(defaultUser.Id, testAccountResult.OwnerId, 'Owner should have changed to default user');
        }
    }
    
    @isTest
    static void EmailListRegexTest()
    {
        String testString1 = 'testemail@test.com';
        String testString2 = 'testemail@test.com;';
        String testString3 = 'testemail@test.com;testemail2@test.com';
        String testString4 = 'testemail@test.com;testemail2@test.com;';
        String testString5 = 'testemail@test.com;testemail2@test.com;testemail3';
        String testString6 = 'testemail1@test.com,testemail2@test.com';
        String testString7 = 'testemail1@test';
        String testString8 = 'TESTEMAIL@TEST.CO.UK';
        String testString9 = 'testemail1@test.comtestemail2@test.com';
        String testString10 = 'testemail1@test.com testemail2@test.com';
        String testString11 = 'testemail1,2@test.com;';
        
        
        System.assertEquals(true, bg_AccountUtils.IsValidEmailList(testString1));
        System.assertEquals(true, bg_AccountUtils.IsValidEmailList(testString2));
        System.assertEquals(true, bg_AccountUtils.IsValidEmailList(testString3));
        System.assertEquals(true, bg_AccountUtils.IsValidEmailList(testString4));
        System.assertEquals(false, bg_AccountUtils.IsValidEmailList(testString5));
        System.assertEquals(false, bg_AccountUtils.IsValidEmailList(testString6));
        System.assertEquals(false, bg_AccountUtils.IsValidEmailList(testString7));
        System.assertEquals(true, bg_AccountUtils.IsValidEmailList(testString8));
        System.assertEquals(false, bg_AccountUtils.IsValidEmailList(testString9));
        System.assertEquals(false, bg_AccountUtils.IsValidEmailList(testString10));
        System.assertEquals(false, bg_AccountUtils.IsValidEmailList(testString11));
        
    }
    
    @isTest
    static void AccountInvoiceEmailsInsertAndUpdateTest()
    {
        String errorMessage;
        Default_Account_Owner_Settings__c setting = new Default_Account_Owner_Settings__c();
        setting.SetupOwnerId=UserInfo.getOrganizationId();
        setting.Name = 'EMEA Default Owner ID';
        setting.EMEA_Default_Owner_ID__c     = '005Si0000004LInIAM';
        insert setting;
        Account testAccount = new Account(Name = 'Test Account', Invoice_Emails__c = 'test@test.com,test2@test.com');
        
        try
        {
            insert testAccount;
        } 
        catch (Exception e)
        {
            errorMessage = e.getMessage();
        }
        
        System.assertNotEquals(null, errorMessage, 'expected validation error');
        System.assert(errorMessage.contains('FIELD_CUSTOM_VALIDATION_EXCEPTION'), 'expected validation error');
        
        errorMessage = null;
        
        testAccount.Invoice_Emails__c = 'test@test.com;';
        insert testAccount;
        
        System.assertNotEquals(null, testAccount.Id, 'expected account to be inserted');
        
        testAccount.Invoice_Emails__c = 'invalid';
        try
        {
            update testAccount;
        }
        catch (Exception e)
        {
            errorMessage = e.getMessage();    
        }
        
        System.assertNotEquals(null, errorMessage, 'expected validation error');
        System.assert(errorMessage.contains('FIELD_CUSTOM_VALIDATION_EXCEPTION'), 'expected validation error');
    }
    
    @isTest
    static void BlockMultipleReplicasTest()
    {
        String replicaRTId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Replica Invoice Account').getRecordTypeId();
        String invoiceRTId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Invoice Account').getRecordTypeId();
        Default_Account_Owner_Settings__c setting = new Default_Account_Owner_Settings__c();
        setting.SetupOwnerId=UserInfo.getOrganizationId();
        setting.Name = 'EMEA Default Owner ID';
        setting.EMEA_Default_Owner_ID__c     = '005Si0000004LInIAM';
        insert setting;
        
        Account myAccount = new Account(Name='B2B');
        insert myAccount;
        
        Account myAccount2 = new Account(Name='B2B2');
        insert myAccount2;
        
        Account replicaAccount = new Account(Name='B2B Replica', RecordTypeId=replicaRTId, B2B_Account__c = myAccount.Id);
        insert replicaAccount;
        
        Account replicaAccount2 = new Account(Name='B2B Replica 2', RecordTypeId=replicaRTId, B2B_Account__c = myAccount.Id);
        
        Boolean error = false;
        try
        {
            insert replicaAccount2;
        }
        catch (Exception e)
        {
            error = true;
        }
        
        System.assertEquals(true, error, 'Expected replica custom validation');
        
        replicaAccount2.B2B_Account__c = myAccount2.Id;
        error = false;
        
        try
        {
            insert replicaAccount2;
        }
        catch (Exception e)
        {
            error = true;
            System.debug(LoggingLevel.ERROR, e.getMessage());
        }
        
        System.assertEquals(false, error, 'Did not expect any error');
        
        
    }
    
    @isTest
    static void BlockMultipleReplicasTest2()
    {
        String replicaRTId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Replica Invoice Account').getRecordTypeId();
        String invoiceRTId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Invoice Account').getRecordTypeId();
        Default_Account_Owner_Settings__c setting = new Default_Account_Owner_Settings__c();
        setting.SetupOwnerId=UserInfo.getOrganizationId();
        setting.Name = 'EMEA Default Owner ID';
        setting.EMEA_Default_Owner_ID__c     = '005Si0000004LInIAM';
        insert setting;
        
        Account myAccount = new Account(Name='B2B');
        insert myAccount;
        
        Account invoiceAcc1 = new Account(Name='B2B Invoice 1', Company__c = 'Test', RecordTypeId=invoiceRTId, B2B_Account__c = myAccount.Id);
        insert invoiceAcc1;
        
        Account invoiceAcc2 = new Account(Name='B2B Invoice 2', Company__c = 'Test2', RecordTypeId=invoiceRTId, B2B_Account__c = myAccount.Id);
        insert invoiceAcc2;
        
        invoiceAcc1.RecordTypeId = replicaRTId;
        update invoiceAcc1;
        
        invoiceAcc2.RecordTypeId = replicaRTId;
        
        Boolean error = false;
        try
        {
            update invoiceAcc2;
        }
        catch (Exception e)
        {
            error = true;
        }
        
        System.assertEquals(true, error, 'Expected replica custom validation');
        
    }
    
    @isTest
    static void ReplicaToInvoiceTest()
    {
        String replicaRTId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Replica Invoice Account').getRecordTypeId();
        String invoiceRTId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Invoice Account').getRecordTypeId();
        Default_Account_Owner_Settings__c setting = new Default_Account_Owner_Settings__c();
        setting.SetupOwnerId=UserInfo.getOrganizationId();
        setting.Name = 'EMEA Default Owner ID';
        setting.EMEA_Default_Owner_ID__c     = '005Si0000004LInIAM';
        insert setting;
        
        /* Default_Account_Owner_Settings__c orgDefaultDisc = new Default_Account_Owner_Settings__c(
SetupOwnerId=UserInfo.getOrganizationId(),
EMEA_Default_Owner_ID__c    ='005Si0000004LInIAM'
);
insert orgDefaultDisc; */
        
        Account myAccount = new Account(Name='B2B Account');
        //   OwnerId
        insert myAccount;
        
        Account replicaAcc1 = new Account(Name='B2B Replica 1', Company__c = 'Test', RecordTypeId=replicaRTId, B2B_Account__c = myAccount.Id);
        insert replicaAcc1;
        
        Account b2bResult = [SELECT Id, Replica_Created__c FROM Account WHERE Id = :myAccount.Id LIMIT 1];
        System.assertEquals(true, b2bResult.Replica_Created__c);
        
        replicaAcc1.RecordTypeId = invoiceRTId;
        
        Boolean error = false;
        try
        {
            update replicaAcc1;
        }
        catch (Exception e)
        {
            error = true;
        }
        
        System.assertEquals(true, error, 'Expected replica custom validation');
        
    }
    
    @isTest
    static void InvoiceToReplicaTest()
    {
        String replicaRTId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Replica Invoice Account').getRecordTypeId();
        String invoiceRTId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Invoice Account').getRecordTypeId();
        Default_Account_Owner_Settings__c setting = new Default_Account_Owner_Settings__c();
        setting.SetupOwnerId=UserInfo.getOrganizationId();
        setting.Name = 'EMEA Default Owner ID';
        setting.EMEA_Default_Owner_ID__c     = '005Si0000004LInIAM';
        insert setting;
        
        Account myAccount = new Account(Name='B2B Account');
        insert myAccount;
        
        Account replicaAcc1 = new Account(Name='B2B Replica 1', Company__c = 'Test', RecordTypeId=invoiceRTId, B2B_Account__c = myAccount.Id);
        insert replicaAcc1;
        
        Account b2bResult = [SELECT Id, Replica_Created__c FROM Account WHERE Id = :myAccount.Id LIMIT 1];
        System.assertEquals(false, b2bResult.Replica_Created__c);
        
        replicaAcc1.RecordTypeId = replicaRTId;
        update replicaAcc1;
        
        b2bResult = [SELECT Id, Replica_Created__c FROM Account WHERE Id = :myAccount.Id LIMIT 1];
        System.assertEquals(true, b2bResult.Replica_Created__c);
        
        
    }
    
    @isTest
    static void AccountHierarchyParentChangeTest()
    {
        // Tests that ultimate parent fields are populated when the parent ID is updated on a child account
        
        Default_Account_Owner_Settings__c setting = new Default_Account_Owner_Settings__c();
        setting.SetupOwnerId=UserInfo.getOrganizationId();
        setting.Name = 'EMEA Default Owner ID';
        setting.EMEA_Default_Owner_ID__c     = '005Si0000004LInIAM';
        insert setting;
        Account testAccountA = new Account(Name = 'Test Account A');
        insert testAccountA;
        
        Account testAccountB = new Account(Name = 'Test Account B');
        insert testAccountB;
        
        Test.startTest();
        
        testAccountB.ParentId = testAccountA.Id;
        update testAccountB;
        
        Test.stopTest();
        
        testAccountA = [SELECT Id, OwnerId, Owner.FirstName, Owner.LastName, Owner.Email, Name FROM Account WHERE Id = :testAccountA.Id LIMIT 1];
        
        Account accResult = [SELECT Id, Ultimate_Parent_Id__c, Ultimate_Parent_Name__c,
                             Ultimate_Parent_Email__c, Ultimate_Parent_Owner__c, Ultimate_Parent_Owner_Id__c
                             FROM Account 
                             WHERE Id = :testAccountB.Id 
                             LIMIT 1];
        
        Assert.areEqual(testAccountA.Id, accResult.Ultimate_Parent_Id__c, 'Unexpected Ultimate_Parent_Id__c');
        Assert.areEqual(testAccountA.Name, accResult.Ultimate_Parent_Name__c, 'Unexpected Ultimate_Parent_Name__c');
        Assert.areEqual(testAccountA.OwnerId, accResult.Ultimate_Parent_Owner_Id__c, 'Unexpected Ultimate_Parent_Owner_Id__c');
        Assert.areEqual(testAccountA.Owner.Email, accResult.Ultimate_Parent_Email__c, 'Unexpected Ultimate_Parent_Email__c');
        Assert.areEqual(testAccountA.Owner.FirstName + ' ' + testAccountA.Owner.LastName, accResult.Ultimate_Parent_Owner__c, 'Unexpected Ultimate_Parent_Owner__c');
    }
    
    @isTest
    static void AccountHierarchyChildInsertTest()
    {
        
        Default_Account_Owner_Settings__c setting = new Default_Account_Owner_Settings__c();
        setting.SetupOwnerId=UserInfo.getOrganizationId();
        setting.Name = 'EMEA Default Owner ID';
        setting.EMEA_Default_Owner_ID__c     = '005Si0000004LInIAM';
        insert setting;
        // Tests that ultimate parent fields are populated when the parent ID is set on insert of a child account
        Account testAccountA = new Account(Name = 'Test Account A');
        insert testAccountA;
        
        Test.startTest();
        
        Account testAccountB = new Account(Name = 'Test Account B', ParentId = testAccountA.Id);
        insert testAccountB;
        
        Test.stopTest();
        
        testAccountA = [SELECT Id, OwnerId, Owner.FirstName, Owner.LastName, Owner.Email, Name FROM Account WHERE Id = :testAccountA.Id LIMIT 1];
        
        Account accResult = [SELECT Id, Ultimate_Parent_Id__c, Ultimate_Parent_Name__c,
                             Ultimate_Parent_Email__c, Ultimate_Parent_Owner__c, Ultimate_Parent_Owner_Id__c
                             FROM Account 
                             WHERE Id = :testAccountB.Id 
                             LIMIT 1];
        
        Assert.areEqual(testAccountA.Id, accResult.Ultimate_Parent_Id__c, 'Unexpected Ultimate_Parent_Id__c');
        Assert.areEqual(testAccountA.Name, accResult.Ultimate_Parent_Name__c, 'Unexpected Ultimate_Parent_Name__c');
        Assert.areEqual(testAccountA.OwnerId, accResult.Ultimate_Parent_Owner_Id__c, 'Unexpected Ultimate_Parent_Owner_Id__c');
        Assert.areEqual(testAccountA.Owner.Email, accResult.Ultimate_Parent_Email__c, 'Unexpected Ultimate_Parent_Email__c');
        Assert.areEqual(testAccountA.Owner.FirstName + ' ' + testAccountA.Owner.LastName, accResult.Ultimate_Parent_Owner__c, 'Unexpected Ultimate_Parent_Owner__c');
        
    }
    
    @isTest
    static void AccountHierarchyOwnerChangeTest()
    {
        // Tests that ultimate parent fields are populated on a parent account and all children when the owner is changed
        
        
        
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        List<Sales_Person_Role_Mapping__mdt> roleMappings = [SELECT Id, MasterLabel, DeveloperName FROM Sales_Person_Role_Mapping__mdt];
        Set<String> mappedRoleNames = new Set<String>();
        for (Sales_Person_Role_Mapping__mdt mapping : roleMappings) {
            mappedRoleNames.add(mapping.MasterLabel);
        }
        List<UserRole> matchedRoles = [SELECT Id FROM UserRole WHERE Name IN :mappedRoleNames LIMIT 1];
        UserRole uRole = !matchedRoles.isEmpty() ? matchedRoles[0] : [SELECT Id FROM UserRole LIMIT 1];
        User testUser = new User(Username='bgotgtest@test.com', LastName='bg_AccountUtilsTest');
        testUser.Email = 'bgotgtest@test.com';
        testUser.Alias = 'bgotg';
        testUser.TimeZoneSidKey = 'Europe/London';
        testUser.LocaleSidKey = 'en_GB';
        testUser.EmailEncodingKey = 'UTF-8';
        testUser.ProfileId = p.Id;
        testUser.LanguageLocaleKey = 'en_US';
        testUser.UserRoleId = uRole.Id;
        insert testUser;
        
        User defaultUser = new User(Username='bgotgtestdefault@test.com', LastName='bg_AccountUtilsTest');
        defaultUser.Email = 'bgotgtest@test.com';
        defaultUser.Alias = 'bgotg';
        defaultUser.TimeZoneSidKey = 'Europe/London';
        defaultUser.LocaleSidKey = 'en_GB';
        defaultUser.EmailEncodingKey = 'UTF-8';
        defaultUser.ProfileId = p.Id;
        defaultUser.LanguageLocaleKey = 'en_US';
        defaultUser.UserRoleId = uRole.Id;
        insert defaultUser;
        
        System.runAs(testUser)
        {
            
            Default_Account_Owner_Settings__c setting = new Default_Account_Owner_Settings__c();
            setting.SetupOwnerId=UserInfo.getOrganizationId();
            setting.Name = 'EMEA Default Owner ID';
            setting.EMEA_Default_Owner_ID__c     = '005Si0000004LInIAM';
            insert setting;
            Account testAccountA = new Account(Name = 'Test Account A');
            insert testAccountA;
            
            
            Account testAccountB = new Account(Name = 'Test Account B', ParentId = testAccountA.Id);
            insert testAccountB;
            
            Test.startTest();
            testAccountA.OwnerId = defaultUser.Id;
            update testAccountA;
            Test.stopTest();
            
            testAccountA = [SELECT Id, OwnerId, Owner.FirstName, Owner.LastName, Owner.Email, Name FROM Account WHERE Id = :testAccountA.Id LIMIT 1];
            
            Account accResult = [SELECT Id, Ultimate_Parent_Id__c, Ultimate_Parent_Name__c,
                                 Ultimate_Parent_Email__c, Ultimate_Parent_Owner__c, Ultimate_Parent_Owner_Id__c
                                 FROM Account 
                                 WHERE Id = :testAccountB.Id 
                                 LIMIT 1];
            
            Assert.areEqual(testAccountA.OwnerId, accResult.Ultimate_Parent_Owner_Id__c, 'Unexpected Ultimate_Parent_Owner_Id__c');
            Assert.areEqual(testAccountA.Owner.Email, accResult.Ultimate_Parent_Email__c, 'Unexpected Ultimate_Parent_Email__c');
            Assert.areEqual(testAccountA.Owner.FirstName + ' ' + testAccountA.Owner.LastName, accResult.Ultimate_Parent_Owner__c, 'Unexpected Ultimate_Parent_Owner__c');
            
        }
    }
    
    @isTest
    static void AccountHierarchyNameChangeTest()
    {
        
        Default_Account_Owner_Settings__c setting = new Default_Account_Owner_Settings__c();
        setting.SetupOwnerId=UserInfo.getOrganizationId();
        setting.Name = 'EMEA Default Owner ID';
        setting.EMEA_Default_Owner_ID__c     = '005Si0000004LInIAM';
        insert setting;
        // Tests that ultimate parent fields are populated on a parent account and all children when the account name is changed
        Account testAccountA = new Account(Name = 'Test Account A');
        insert testAccountA;
        
        
        Account testAccountB = new Account(Name = 'Test Account B', ParentId = testAccountA.Id);
        insert testAccountB;
        
        Test.startTest();
        testAccountA.Name = 'Test account A2';
        update testAccountA;
        Test.stopTest();
        
        testAccountA = [SELECT Id, OwnerId, Owner.FirstName, Owner.LastName, Owner.Email, Name FROM Account WHERE Id = :testAccountA.Id LIMIT 1];
        
        Account accResult = [SELECT Id, Ultimate_Parent_Id__c, Ultimate_Parent_Name__c,
                             Ultimate_Parent_Email__c, Ultimate_Parent_Owner__c, Ultimate_Parent_Owner_Id__c
                             FROM Account 
                             WHERE Id = :testAccountB.Id 
                             LIMIT 1];
        
        Assert.areEqual(testAccountA.Name, accResult.Ultimate_Parent_Name__c, 'Unexpected Ultimate_Parent_Name__c');    
    }
    
    @isTest
    static void AccountHierarchyNullChangeTest()
    {
        
        Default_Account_Owner_Settings__c setting = new Default_Account_Owner_Settings__c();
        setting.SetupOwnerId=UserInfo.getOrganizationId();
        setting.Name = 'EMEA Default Owner ID';
        setting.EMEA_Default_Owner_ID__c     = '005Si0000004LInIAM';
        insert setting;
        // Tests that ultimate parent fields are populated on a parent account and all children when an ultimate parent field is cleared
        Account testAccountA = new Account(Name = 'Test Account A');
        insert testAccountA;
        
        
        Account testAccountB = new Account(Name = 'Test Account B', ParentId = testAccountA.Id);
        insert testAccountB;
        
        Test.startTest();
        testAccountB.Ultimate_Parent_Name__c = null;
        update testAccountB;
        Test.stopTest();
        
        testAccountA = [SELECT Id, OwnerId, Owner.FirstName, Owner.LastName, Owner.Email, Name FROM Account WHERE Id = :testAccountA.Id LIMIT 1];
        
        Account accResult = [SELECT Id, Ultimate_Parent_Id__c, Ultimate_Parent_Name__c,
                             Ultimate_Parent_Email__c, Ultimate_Parent_Owner__c, Ultimate_Parent_Owner_Id__c
                             FROM Account 
                             WHERE Id = :testAccountB.Id 
                             LIMIT 1];
        
        Assert.areEqual(testAccountA.Name, accResult.Ultimate_Parent_Name__c, 'Unexpected Ultimate_Parent_Name__c');    
    }
    
    @isTest
    static void AccountHierarchyChainBreakTest()
    {
        
        Default_Account_Owner_Settings__c setting = new Default_Account_Owner_Settings__c();
        setting.SetupOwnerId=UserInfo.getOrganizationId();
        setting.Name = 'EMEA Default Owner ID';
        setting.EMEA_Default_Owner_ID__c     = '005Si0000004LInIAM';
        insert setting;
        // Tests that ultimate parent fields are populated on a parent account and all children when it is removed from an existing chain
        Account testAccountA = new Account(Name = 'Test Account A');
        insert testAccountA;
        
        
        Account testAccountB = new Account(Name = 'Test Account B', ParentId = testAccountA.Id);
        insert testAccountB;
        
        Account testAccountC = new Account(Name = 'Test Account C', ParentId = testAccountB.Id);
        insert testAccountC;
        
        Test.startTest();
        testAccountB.ParentId = null;
        update testAccountB;
        Test.stopTest();
        
        testAccountA = [SELECT Id, OwnerId, Owner.FirstName, Owner.LastName, Owner.Email, Name FROM Account WHERE Id = :testAccountA.Id LIMIT 1];
        
        Account accResult = [SELECT Id, Ultimate_Parent_Id__c, Ultimate_Parent_Name__c,
                             Ultimate_Parent_Email__c, Ultimate_Parent_Owner__c, Ultimate_Parent_Owner_Id__c
                             FROM Account 
                             WHERE Id = :testAccountB.Id 
                             LIMIT 1];
        
        Account accResult2 = [SELECT Id, Ultimate_Parent_Id__c, Ultimate_Parent_Name__c,
                              Ultimate_Parent_Email__c, Ultimate_Parent_Owner__c, Ultimate_Parent_Owner_Id__c
                              FROM Account 
                              WHERE Id = :testAccountC.Id 
                              LIMIT 1];
        
        Assert.areEqual(accResult.Ultimate_Parent_Id__c, accResult2.Ultimate_Parent_Id__c, 'Unexpected Ultimate_Parent_Id__c');    
    }
    
    @isTest
    static void testPaymentTermsUpdateOnAccountChange(){
        Default_Account_Owner_Settings__c setting = new Default_Account_Owner_Settings__c();
        setting.SetupOwnerId=UserInfo.getOrganizationId();
        setting.Name = 'EMEA Default Owner ID';
        setting.EMEA_Default_Owner_ID__c     = '005Si0000004LInIAM';
        insert setting;
        
        
        List<Account> testAccounts = new List<Account>{
            new Account(Name = 'Test Account 1', Customer_Payment_Terms__c = '30 days from invoice date'),
                new Account(Name = 'Test Account 2', Customer_Payment_Terms__c = 'Due immediately'),
                new Account(Name = 'Test Account 3', Customer_Payment_Terms__c = '90 days from invoice date')
                };
                    insert testAccounts;
        
        
        List<SBQQ__Quote__c> testQuotes = new List<SBQQ__Quote__c>();
        for (Account acc : testAccounts) {
            testQuotes.add(new SBQQ__Quote__c(
                SBQQ__Account__c = acc.Id,
                SBQQ__Status__c = 'Draft',
                SBQQ__Primary__c = true
            ));
            testQuotes.add(new SBQQ__Quote__c(
                SBQQ__Account__c = acc.Id,
                SBQQ__Status__c = 'Approved', // Should not be updated
                SBQQ__Primary__c = false
            ));
        }
        insert testQuotes; 
        
        for (Account acc : testAccounts) {
            if (acc.Customer_Payment_Terms__c == '30 days from invoice date') {
                acc.Customer_Payment_Terms__c = '45 days from invoice date';
            } else if (acc.Customer_Payment_Terms__c == 'Due immediately') {
                acc.Customer_Payment_Terms__c = '30 days from invoice date';
            } else if (acc.Customer_Payment_Terms__c == '90 days from invoice date') {
                acc.Customer_Payment_Terms__c = '60 days from invoice date';
            }
        }
        
        Test.startTest();
        update testAccounts;
        Test.stopTest();
        
        List<SBQQ__Quote__c> updatedQuotes = [
            SELECT Id, SBQQ__PaymentTerms__c, SBQQ__Status__c, SBQQ__Account__c 
            FROM SBQQ__Quote__c 
            WHERE SBQQ__Status__c != 'Approved'
        ];
        System.assertEquals(3, updatedQuotes.size(), 'Should update 3 non-approved quotes');

        for (SBQQ__Quote__c quote : updatedQuotes) {
            Account relatedAccount = [SELECT Customer_Payment_Terms__c FROM Account WHERE Id = :quote.SBQQ__Account__c];
            
            if (relatedAccount.Customer_Payment_Terms__c == '45 days from invoice date') {
               // System.assertEquals('Net 45', quote.SBQQ__PaymentTerms__c, '45 days should map to Net 45');
            } else if (relatedAccount.Customer_Payment_Terms__c == 'Payment in Advance') {
               // System.assertEquals('Due on receipt', quote.SBQQ__PaymentTerms__c, 'Payment in Advance should map to Due on receipt');
            } else if (relatedAccount.Customer_Payment_Terms__c == '60 days from invoice date') {
              //  System.assertEquals('Net 60', quote.SBQQ__PaymentTerms__c, '60 days should map to Net 60');
            }
        }  
    }
}
