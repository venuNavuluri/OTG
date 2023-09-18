@isTest
public class bg_ClearDuplicateBypassTest
{
    @isTest
    static void ClearDuplicateBypassTest()
    {
        Account testAccount = new Account();
        testAccount.Name = 'Test';
        testAccount.Bypass_Duplicate_Rule__c = true;
        insert testAccount;

        bg_ClearDuplicateBypass.ClearDuplicateInput input = new bg_ClearDuplicateBypass.ClearDuplicateInput();
        input.objectName = 'Account';
        input.recordId = testAccount.Id;

        Test.startTest();
        bg_ClearDuplicateBypass.ClearDuplicateBypass(new List<bg_ClearDuplicateBypass.ClearDuplicateInput>{input});
        Test.stopTest();

        Account accResult = [SELECT Id, Bypass_Duplicate_Rule__c FROM Account WHERE Id = :testAccount.Id LIMIT 1];
        Assert.areEqual(false, accResult.Bypass_Duplicate_Rule__c, 'Duplicate bypass not cleared');
    }

    @isTest
    static void ClearDuplicateBypassTestDuplicateIds()
    {
        Account testAccount = new Account();
        testAccount.Name = 'Test';
        testAccount.Bypass_Duplicate_Rule__c = true;
        insert testAccount;

        bg_ClearDuplicateBypass.ClearDuplicateInput input = new bg_ClearDuplicateBypass.ClearDuplicateInput();
        input.objectName = 'Account';
        input.recordId = testAccount.Id;

        Test.startTest();
        bg_ClearDuplicateBypass.ClearDuplicateBypass(new List<bg_ClearDuplicateBypass.ClearDuplicateInput>{input,input});
        Test.stopTest();

        Account accResult = [SELECT Id, Bypass_Duplicate_Rule__c FROM Account WHERE Id = :testAccount.Id LIMIT 1];
        Assert.areEqual(false, accResult.Bypass_Duplicate_Rule__c, 'Duplicate bypass not cleared');
    }
}