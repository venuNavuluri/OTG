@IsTest
private class CreateOrderFromQuoteControllerTest {

    @TestSetup
    static void setupData() {
        TestDataFactory_OTG.enableOrgVRConfig();
        TestDataFactory_OTG.primeDefaultOwnerAllRegions(UserInfo.getUserId());

        TestDataFactory_OTG.QuoteContext qc =
            TestDataFactory_OTG.buildDraftQuoteContext('Americas', false, false);

        SBQQ__QuoteLineGroup__c userQlg =
            TestDataFactory_OTG.createQuoteLineGroup(qc.quote.Id, 'User QLG', false, 1);

        Date s = Date.today(), e = s.addMonths(12);
        TestDataFactory_OTG.createQuoteLine(qc.quote.Id, userQlg.Id, qc.pbe.Id, 1, null, 100, s, e, null);

        Contract ctr = TestDataFactory_OTG.createContractBasic(qc.b2bAccount.Id, 'USD', Date.today(), 12, null);
        Package__c pkg = TestDataFactory_OTG.createPackageLinkedToQLG(ctr.Id, qc.quote.Id, userQlg, 1);

        Vessel__c v = TestDataFactory_OTG.getOrCreateVesselCached();
        TestDataFactory_OTG.createInstallation(pkg.Id, v.Id, 'Pending Implementation');
    }

    @IsTest
    static void test_validate_and_order_success() {
        SBQQ__QuoteLineGroup__c qlg = [
            SELECT Id, SBQQ__Quote__c
            FROM SBQQ__QuoteLineGroup__c
            WHERE Name = 'User QLG'
            LIMIT 1
        ];

        Test.startTest();
        // 1) Validate (should pass)
        String validation = CreateOrderFromQuoteController.validateInstallationCount(qlg.SBQQ__Quote__c);
        // 2) Order the quote (should succeed)
        String result = CreateOrderFromQuoteController.updateQuoteToOrdered(qlg.SBQQ__Quote__c);
        Test.stopTest();

        System.assertEquals('SUCCESS', validation, 'Validation should pass with matching counts.');
        System.assertEquals('SUCCESS', result, 'Ordering should return SUCCESS');

        SBQQ__Quote__c refreshed = [
            SELECT Id, SBQQ__Ordered__c
            FROM SBQQ__Quote__c
            WHERE Id = :qlg.SBQQ__Quote__c
            LIMIT 1
        ];
        System.assertEquals(true, refreshed.SBQQ__Ordered__c, 'Quote should be marked as Ordered.');
    }
}