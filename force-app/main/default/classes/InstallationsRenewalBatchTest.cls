@IsTest
private class InstallationsRenewalBatchTest {

    @IsTest
    static void testBatchRunsWithoutSubscriptions() {
        TestDataFactory_OTG.enableOrgVRConfig();
        TestDataFactory_OTG.primeDefaultOwnerAllRegions(UserInfo.getUserId());
        InstallationTriggerHandler.setBypassForTests(true);

        TestDataFactory_OTG.OrderContext ctx =
            TestDataFactory_OTG.buildOrderContext('Americas', 'Renewal', 'Draft', false, false);

        Contract ctr = [
            SELECT Id, StartDate, EndDate
            FROM Contract
            WHERE Id = :ctx.packageRec.Contract__c
        ];

        Installation__c instUpdate = new Installation__c(
            Id = ctx.installation.Id,
            Contract__c = ctr.Id,
            Quote_Line_Group__c = ctx.qlg.Id,
            Order__c = ctx.orderRec.Id,
            Installation_End_Date__c = ctr.EndDate,
            Installation_Order_Status__c = 'Active'
        );
        update instUpdate;

        Test.startTest();
        Database.executeBatch(new InstallationsRenewalBatch(new Set<Id>{ ctx.installation.Id }), 50);
        Test.stopTest();

        Integer lineCount = [
            SELECT COUNT()
            FROM Installation_Line__c
            WHERE Installation__c = :ctx.installation.Id
        ];
        System.assertEquals(0, lineCount, 'No installation lines expected without subscriptions.');
    }
}