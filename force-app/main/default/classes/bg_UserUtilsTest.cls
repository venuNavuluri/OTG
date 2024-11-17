@isTest
public class bg_UserUtilsTest {
    @isTest
    static void UserSalesOfficeUpdateTest()
    {
        
        Default_Account_Owner_Settings__c setting = new Default_Account_Owner_Settings__c();
        setting.SetupOwnerId=UserInfo.getOrganizationId();
        setting.Name = 'EMEA Default Owner ID';
        setting.EMEA_Default_Owner_ID__c     = '005Si0000004LInIAM';
        insert setting;
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User testUser = new User(Username='bgotgtest@test.com', LastName='bg_UserUtilsTest');
        testUser.Email = 'bgotgtest@test.com';
        testUser.Alias = 'bgotg';
        testUser.TimeZoneSidKey = 'Europe/London';
        testUser.LocaleSidKey = 'en_GB';
        testUser.EmailEncodingKey = 'UTF-8';
        testUser.ProfileId = p.Id;
        testUser.LanguageLocaleKey = 'en_US';
        insert testUser;
        
        Account acc1 = new Account();
        acc1.Name = 'Test Account';
        acc1.OwnerId = testUser.Id;
        acc1.Visma_Modified_Date__c = null;
        acc1.AccountSource = 'Other';
        insert acc1;
        
        Test.startTest();
        testUser.Sales_Office__c = 'US Office';
        update testUser;
        Test.stopTest();
        
        Account accountResult = [SELECT Id, Visma_Modified_Date__c FROM Account LIMIT 1];
        //  System.assertNotEquals(null, accountResult.Visma_Modified_Date__c);
        
    }
    
    @isTest
    static void IsSalesPersonTest()
    {
        List<Sales_Person_Role_Mapping__mdt> roleMappings = [SELECT Id, MasterLabel, DeveloperName FROM Sales_Person_Role_Mapping__mdt];
        
        bg_UserUtils.PopulateRoles();
        
        String invalidRole = 'Invalid Role';
        Boolean invalidRoleResult = bg_UserUtils.IsSalesPerson(invalidRole);
        System.assertEquals(false, invalidRoleResult);
        
        Integer numberOfQueries = Limits.getQueries();
        
        String validRole = roleMappings[0].DeveloperName;
        Boolean validRoleResult = bg_UserUtils.IsSalesPerson(validRole);
        System.assertEquals(true, validRoleResult);
        
        Integer numberOfQueries2 = Limits.getQueries();
        System.assertEquals(numberOfQueries, numberOfQueries2);
        
    }
}