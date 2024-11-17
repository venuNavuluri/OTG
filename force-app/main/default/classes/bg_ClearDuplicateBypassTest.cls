/*
*   
*   bg_ClearDuplicateBypassTest
*   Author  : BrightGen Limited
*   Created : ?
*
*   Class   : Test class for bg_ClearDuplicateBypass
*           
*   Changes : 29/11/2023 ADS - Case 65144 - Handle Apex Collections when an Account appears more than once in the List
*/
@isTest
public class bg_ClearDuplicateBypassTest
{
    @isTest
    static void ClearDuplicateBypassTest()
    {
        
        Default_Account_Owner_Settings__c setting = new Default_Account_Owner_Settings__c();
        setting.SetupOwnerId=UserInfo.getOrganizationId();
        setting.Name = 'EMEA Default Owner ID';
        setting.EMEA_Default_Owner_ID__c     = '005Si0000004LInIAM';
        insert setting;
        Account testAccount = new Account();
        testAccount.Name = 'Test';
        testAccount.Bypass_Duplicate_Rule__c = true;
        insert testAccount;
        
        Test.startTest();
        bg_ClearDuplicateBypass.ClearDuplicateBypass(new List<List<Account>>{new List<Account>{testAccount}});
        Test.stopTest();
        
        Account accResult = [SELECT Id, Bypass_Duplicate_Rule__c FROM Account WHERE Id = :testAccount.Id LIMIT 1];
        Assert.areEqual(false, accResult.Bypass_Duplicate_Rule__c, 'Duplicate bypass not cleared');
    }
    
    @isTest
    static void ClearDuplicateBypassTestDuplicateIds()
    {
        
        Default_Account_Owner_Settings__c setting = new Default_Account_Owner_Settings__c();
        setting.SetupOwnerId=UserInfo.getOrganizationId();
        setting.Name = 'EMEA Default Owner ID';
        setting.EMEA_Default_Owner_ID__c     = '005Si0000004LInIAM';
        insert setting;
        Account testAccount = new Account();
        testAccount.Name = 'Test';
        testAccount.Bypass_Duplicate_Rule__c = true;
        insert testAccount;
        
        Test.startTest();
        bg_ClearDuplicateBypass.ClearDuplicateBypass(new List<List<Account>>{new List<Account>{testAccount}});
        Test.stopTest();
        
        Account accResult = [SELECT Id, Bypass_Duplicate_Rule__c FROM Account WHERE Id = :testAccount.Id LIMIT 1];
        Assert.areEqual(false, accResult.Bypass_Duplicate_Rule__c, 'Duplicate bypass not cleared');
    }
    
    @isTest
    static void ClearDuplicateBypassTestCollection()
    {
        
        Default_Account_Owner_Settings__c setting = new Default_Account_Owner_Settings__c();
        setting.SetupOwnerId=UserInfo.getOrganizationId();
        setting.Name = 'EMEA Default Owner ID';
        setting.EMEA_Default_Owner_ID__c     = '005Si0000004LInIAM';
        insert setting;
        Account testAccount = new Account();
        testAccount.Name = 'Test';
        testAccount.Bypass_Duplicate_Rule__c = true;
        insert testAccount;
        
        // before Case 65144, force the error: "System.ListException: Duplicate id in list" by adding the same Account more than once
        List<Account> theAccountList = new List<Account>();
        theAccountList.add(testAccount);
        theAccountList.add(testAccount);
        
        Test.startTest();
        bg_ClearDuplicateBypass.ClearDuplicateBypass(new List<List<Account>>{theAccountList});
        Test.stopTest();
        
        Account accResult = [SELECT Id, Bypass_Duplicate_Rule__c FROM Account WHERE Id = :testAccount.Id LIMIT 1];
        Assert.areEqual(false, accResult.Bypass_Duplicate_Rule__c, 'Duplicate bypass not cleared');
    }  
}