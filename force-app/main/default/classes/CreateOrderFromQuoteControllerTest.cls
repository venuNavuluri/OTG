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
        update new Product2(
            Id = qc.product.Id,
            Addendum_Requires_SOW__c = 'Yes'
        );

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
        String result = CreateOrderFromQuoteController.updateQuoteToOrdered(qlg.SBQQ__Quote__c, false);
        Test.stopTest();

        System.assertEquals('SUCCESS', validation, 'Validation should pass with matching counts.');
        System.assertEquals('SUCCESS', result, 'Ordering should return SUCCESS');

        SBQQ__Quote__c refreshed = [
            SELECT Id, SBQQ__Ordered__c, Requires_Service_Order__c
            FROM SBQQ__Quote__c
            WHERE Id = :qlg.SBQQ__Quote__c
            LIMIT 1
        ];
        System.assertEquals(true, refreshed.SBQQ__Ordered__c, 'Quote should be marked as Ordered.');
        System.assertEquals(true, refreshed.Requires_Service_Order__c, 'Quote should require service order when any quote product requires SOW.');
    }

    @IsTest
    static void test_validate_returns_all_package_quantity_mismatch_messages() {
        SBQQ__QuoteLineGroup__c qlg = [
            SELECT Id, SBQQ__Quote__c, Installation_Quantity__c
            FROM SBQQ__QuoteLineGroup__c
            WHERE Name = 'User QLG'
            LIMIT 1
        ];
        qlg.Installation_Quantity__c = 2;
        update qlg;

        Package__c pkg = [
            SELECT Id, Name, Contract__c
            FROM Package__c
            WHERE Temp_Quote_Line_Group__c = :qlg.Id
            LIMIT 1
        ];
        Contract contractRec = [
            SELECT Id
            FROM Contract
            WHERE Id = :pkg.Contract__c
            LIMIT 1
        ];
        SBQQ__QuoteLineGroup__c secondQlg = TestDataFactory_OTG.createQuoteLineGroup(
            qlg.SBQQ__Quote__c,
            'Second User QLG',
            false,
            3
        );
        Package__c secondPkg = TestDataFactory_OTG.createPackageLinkedToQLG(
            contractRec.Id,
            qlg.SBQQ__Quote__c,
            secondQlg,
            3
        );

        Test.startTest();
        String validation = CreateOrderFromQuoteController.validateInstallationCount(qlg.SBQQ__Quote__c);
        Test.stopTest();

        System.assert(
            validation.contains('- <strong>' + pkg.Name + '</strong>: 1 active installation(s), Installation Quantity 2'),
            'Mismatch validation should include package name, active installations, and expected quantity. Actual: ' + validation
        );
        System.assert(
            validation.contains('- <strong>' + secondPkg.Name + '</strong>: 0 active installation(s), Installation Quantity 3'),
            'Mismatch validation should include all mismatched packages. Actual: ' + validation
        );
        System.assert(
            validation.contains('Please update the package installations or package quantities before creating the order.'),
            'Mismatch validation should include the user action. Actual: ' + validation
        );
        System.assert(
            validation.contains('\n'),
            'Mismatch validation should be multiline for readability. Actual: ' + validation
        );
    }
}
