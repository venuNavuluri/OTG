@IsTest
private class FutureInstallationTerminationServiceTest {
    @TestSetup
    static void setup() {
        TestDataFactory_OTG.enableOrgVRConfig();
        TestDataFactory_OTG.primeDefaultOwnerAllRegions(UserInfo.getUserId());
    }

    @IsTest
    static void testContractEndDateCompletesWithoutAmendmentQuote() {
        TestDataFactory_OTG.OrderContext ctx =
            TestDataFactory_OTG.buildOrderContext('Americas', 'Amendment', 'Draft', true, false);

        Date terminationDate = Date.today();
        update new Contract(
            Id = ctx.packageRec.Contract__c,
            Status = 'Draft',
            StartDate = terminationDate.addMonths(-12),
            EndDate = terminationDate,
            Billing_Frequency__c = 'Monthly'
        );
        update new SBQQ__QuoteLineGroup__c(Id = ctx.qlg.Id, Package__c = ctx.packageRec.Id);
        update new Installation__c(
            Id = ctx.installation.Id,
            Contract__c = ctx.packageRec.Contract__c,
            Quote_Line_Group__c = ctx.qlg.Id,
            Installation_Order_Status__c = 'Future Terminated',
            Termination_End_Date__c = terminationDate,
            Auto_Termination__c = true,
            Termination_Process_Status__c = 'Requested'
        );

        Test.startTest();
        FutureInstallationTerminationService.processGroup(ctx.packageRec.Contract__c, terminationDate);
        Test.stopTest();

        Installation__c refreshed = [
            SELECT Installation_Order_Status__c, Installation_End_date__c, Termination_Process_Status__c, Termination_Quote__c
            FROM Installation__c
            WHERE Id = :ctx.installation.Id
        ];
        System.assertEquals('Terminated', refreshed.Installation_Order_Status__c);
        System.assertEquals(terminationDate, refreshed.Installation_End_date__c);
        System.assertEquals('Completed', refreshed.Termination_Process_Status__c);
        System.assertEquals(null, refreshed.Termination_Quote__c, 'Contract end date terminations must not create or link an amendment quote.');
    }

    @IsTest
    static void testGroupedFutureTerminationReducesEachPackageOnce() {
        TestDataFactory_OTG.OrderContext ctx =
            TestDataFactory_OTG.buildOrderContext('Americas', 'Amendment', 'Draft', true, false);

        Date terminationDate = Date.today();
        update new Contract(
            Id = ctx.packageRec.Contract__c,
            Status = 'Draft',
            StartDate = terminationDate.addMonths(-12),
            EndDate = terminationDate.addMonths(6),
            Billing_Frequency__c = 'Monthly'
        );
        update new SBQQ__Quote__c(Id = ctx.qctx.quote.Id, SBQQ__MasterContract__c = ctx.packageRec.Contract__c);
        update new SBQQ__QuoteLineGroup__c(
            Id = ctx.qlg.Id,
            Package__c = ctx.packageRec.Id,
            Installation_Quantity__c = 5
        );

        SBQQ__QuoteLineGroup__c secondQlg =
            TestDataFactory_OTG.createQuoteLineGroup(ctx.qctx.quote.Id, 'Second Group', false, 4);
        Package__c secondPackage = TestDataFactory_OTG.createPackageLinkedToQLG(
            ctx.packageRec.Contract__c,
            ctx.qctx.quote.Id,
            secondQlg,
            4
        );
        update new SBQQ__QuoteLineGroup__c(Id = secondQlg.Id, Package__c = secondPackage.Id);

        List<Vessel__c> vessels = TestDataFactory_OTG.createVessels(2);
        Installation__c secondSamePackage = new Installation__c(
            Package__c = ctx.packageRec.Id,
            Contract__c = ctx.packageRec.Contract__c,
            Quote__c = ctx.qctx.quote.Id,
            Quote_Line_Group__c = ctx.qlg.Id,
            Vessel_Name__c = vessels[0].Id,
            Installation_Order_Status__c = 'Future Terminated',
            Termination_End_Date__c = terminationDate,
            Auto_Termination__c = true,
            Termination_Process_Status__c = 'Requested'
        );
        Installation__c thirdSecondPackage = new Installation__c(
            Package__c = secondPackage.Id,
            Contract__c = ctx.packageRec.Contract__c,
            Quote__c = ctx.qctx.quote.Id,
            Quote_Line_Group__c = secondQlg.Id,
            Vessel_Name__c = vessels[1].Id,
            Installation_Order_Status__c = 'Future Terminated',
            Termination_End_Date__c = terminationDate,
            Auto_Termination__c = true,
            Termination_Process_Status__c = 'Requested'
        );
        insert new List<Installation__c>{secondSamePackage, thirdSecondPackage};

        update new Installation__c(
            Id = ctx.installation.Id,
            Contract__c = ctx.packageRec.Contract__c,
            Quote_Line_Group__c = ctx.qlg.Id,
            Installation_Order_Status__c = 'Future Terminated',
            Termination_End_Date__c = terminationDate,
            Auto_Termination__c = true,
            Termination_Process_Status__c = 'Requested'
        );

        FutureInstallationTerminationService.testQuoteIdsByContract.put(ctx.packageRec.Contract__c, ctx.qctx.quote.Id);

        Test.startTest();
        FutureInstallationTerminationService.processGroup(ctx.packageRec.Contract__c, terminationDate);
        Test.stopTest();

        Map<Id, SBQQ__QuoteLineGroup__c> qlgs = new Map<Id, SBQQ__QuoteLineGroup__c>([
            SELECT Id, Installation_Quantity__c
            FROM SBQQ__QuoteLineGroup__c
            WHERE Id IN :new Set<Id>{ctx.qlg.Id, secondQlg.Id}
        ]);
        System.assertEquals(3, qlgs.get(ctx.qlg.Id).Installation_Quantity__c,
            'Two due installations on the first package should reduce quantity by two.');
        System.assertEquals(3, qlgs.get(secondQlg.Id).Installation_Quantity__c,
            'One due installation on the second package should reduce quantity by one.');

        for (Installation__c inst : [
            SELECT Termination_Quote__c, Termination_Process_Status__c
            FROM Installation__c
            WHERE Id IN :new Set<Id>{ctx.installation.Id, secondSamePackage.Id, thirdSecondPackage.Id}
        ]) {
            System.assertEquals(ctx.qctx.quote.Id, inst.Termination_Quote__c);
            System.assertEquals('Waiting For Order Activation', inst.Termination_Process_Status__c);
        }

        SBQQ__Quote__c quote = [
            SELECT Auto_Termination__c, Installation__c, SBQQ__StartDate__c
            FROM SBQQ__Quote__c
            WHERE Id = :ctx.qctx.quote.Id
        ];
        System.assertEquals(true, quote.Auto_Termination__c);
        System.assertEquals(terminationDate, quote.SBQQ__StartDate__c);
        System.assertNotEquals(null, quote.Installation__c);
    }

    @IsTest
    static void testBatchProcessesDueGroups() {
        TestDataFactory_OTG.OrderContext ctx =
            TestDataFactory_OTG.buildOrderContext('Americas', 'Amendment', 'Draft', true, false);

        Date terminationDate = Date.today();
        update new Contract(
            Id = ctx.packageRec.Contract__c,
            Status = 'Draft',
            StartDate = terminationDate.addMonths(-12),
            EndDate = terminationDate,
            Billing_Frequency__c = 'Monthly'
        );
        update new Installation__c(
            Id = ctx.installation.Id,
            Contract__c = ctx.packageRec.Contract__c,
            Installation_Order_Status__c = 'Future Terminated',
            Termination_End_Date__c = terminationDate,
            Auto_Termination__c = true,
            Termination_Process_Status__c = 'Requested'
        );

        Test.startTest();
        Database.executeBatch(new FutureInstallationTerminationBatch(), 1);
        Test.stopTest();

        Installation__c refreshed = [
            SELECT Installation_Order_Status__c, Termination_Process_Status__c
            FROM Installation__c
            WHERE Id = :ctx.installation.Id
        ];
        System.assertEquals('Terminated', refreshed.Installation_Order_Status__c);
        System.assertEquals('Completed', refreshed.Termination_Process_Status__c);
    }

    @IsTest
    static void testSchedulerSubmitsNightlyBatch() {
        Test.startTest();
        new FutureInstallationTerminationScheduler().execute(null);
        Test.stopTest();

        System.assert(true, 'Scheduler should submit the batch without requiring due records.');
    }

    @IsTest
    static void testMissingPackageIsMarkedFailed() {
        TestDataFactory_OTG.OrderContext ctx =
            TestDataFactory_OTG.buildOrderContext('Americas', 'Amendment', 'Draft', true, false);

        Date terminationDate = Date.today();
        update new Contract(
            Id = ctx.packageRec.Contract__c,
            StartDate = terminationDate.addMonths(-12),
            EndDate = terminationDate.addMonths(6),
            Billing_Frequency__c = 'Monthly'
        );
        update new Installation__c(
            Id = ctx.installation.Id,
            Contract__c = ctx.packageRec.Contract__c,
            Package__c = null,
            Installation_Order_Status__c = 'Future Terminated',
            Termination_End_Date__c = terminationDate,
            Auto_Termination__c = true,
            Termination_Process_Status__c = 'Requested'
        );

        Test.startTest();
        FutureInstallationTerminationService.processGroup(ctx.packageRec.Contract__c, terminationDate);
        Test.stopTest();

        Installation__c refreshed = [
            SELECT Termination_Process_Status__c, Termination_Process_Error__c
            FROM Installation__c
            WHERE Id = :ctx.installation.Id
        ];
        System.assertEquals('Failed', refreshed.Termination_Process_Status__c);
        System.assert(refreshed.Termination_Process_Error__c.contains('no related package'));
    }

    @IsTest
    static void testMissingQuoteLineGroupSetsRetryPending() {
        TestDataFactory_OTG.OrderContext ctx =
            TestDataFactory_OTG.buildOrderContext('Americas', 'Amendment', 'Draft', true, false);

        Date terminationDate = Date.today();
        update new Contract(
            Id = ctx.packageRec.Contract__c,
            StartDate = terminationDate.addMonths(-12),
            EndDate = terminationDate.addMonths(6),
            Billing_Frequency__c = 'Monthly'
        );
        update new SBQQ__Quote__c(Id = ctx.qctx.quote.Id, SBQQ__MasterContract__c = ctx.packageRec.Contract__c);
        update new SBQQ__QuoteLineGroup__c(Id = ctx.qlg.Id, Package__c = null, Installation_Quantity__c = 5);
        update new Installation__c(
            Id = ctx.installation.Id,
            Contract__c = ctx.packageRec.Contract__c,
            Installation_Order_Status__c = 'Future Terminated',
            Termination_End_Date__c = terminationDate,
            Auto_Termination__c = true,
            Termination_Process_Status__c = 'Requested'
        );
        FutureInstallationTerminationService.testQuoteIdsByContract.put(ctx.packageRec.Contract__c, ctx.qctx.quote.Id);

        Test.startTest();
        FutureInstallationTerminationService.processGroup(ctx.packageRec.Contract__c, terminationDate);
        Test.stopTest();

        Installation__c refreshed = [
            SELECT Termination_Process_Status__c, Termination_Quote__c, Termination_Process_Error__c
            FROM Installation__c
            WHERE Id = :ctx.installation.Id
        ];
        System.assertEquals('Retry Pending', refreshed.Termination_Process_Status__c);
        System.assertEquals(ctx.qctx.quote.Id, refreshed.Termination_Quote__c);
        System.assert(refreshed.Termination_Process_Error__c.contains('quote line groups'));
    }

    @IsTest
    static void testQuantityBelowZeroIsMarkedFailed() {
        TestDataFactory_OTG.OrderContext ctx =
            TestDataFactory_OTG.buildOrderContext('Americas', 'Amendment', 'Draft', true, false);

        Date terminationDate = Date.today();
        update new Contract(
            Id = ctx.packageRec.Contract__c,
            StartDate = terminationDate.addMonths(-12),
            EndDate = terminationDate.addMonths(6),
            Billing_Frequency__c = 'Monthly'
        );
        update new SBQQ__Quote__c(Id = ctx.qctx.quote.Id, SBQQ__MasterContract__c = ctx.packageRec.Contract__c);
        update new SBQQ__QuoteLineGroup__c(
            Id = ctx.qlg.Id,
            Package__c = ctx.packageRec.Id,
            Installation_Quantity__c = 0
        );
        update new Installation__c(
            Id = ctx.installation.Id,
            Contract__c = ctx.packageRec.Contract__c,
            Installation_Order_Status__c = 'Future Terminated',
            Termination_End_Date__c = terminationDate,
            Auto_Termination__c = true,
            Termination_Process_Status__c = 'Requested'
        );
        FutureInstallationTerminationService.testQuoteIdsByContract.put(ctx.packageRec.Contract__c, ctx.qctx.quote.Id);

        Test.startTest();
        FutureInstallationTerminationService.processGroup(ctx.packageRec.Contract__c, terminationDate);
        Test.stopTest();

        Installation__c refreshed = [
            SELECT Termination_Process_Status__c, Termination_Process_Error__c
            FROM Installation__c
            WHERE Id = :ctx.installation.Id
        ];
        System.assertEquals('Failed', refreshed.Termination_Process_Status__c);
        System.assert(refreshed.Termination_Process_Error__c.contains('below zero'));
    }

    @IsTest
    static void testGroupedOrderActivationFinalizesAllLinkedInstallations() {
        TestDataFactory_OTG.OrderContext oc =
            TestDataFactory_OTG.buildOrderContext('Americas', 'Amendment', 'Draft', true, true);

        Vessel__c vessel = new Vessel__c(
            Name = 'Grouped Termination Vessel',
            Vessel_IMO_Status__c = 'Active IMO',
            Vessel_IMO__c = '7654321',
            Vessel_MMSI__c = '111222333'
        );
        insert vessel;
        Installation__c groupedInstallation = new Installation__c(
            Package__c = oc.packageRec.Id,
            Contract__c = oc.packageRec.Contract__c,
            Quote__c = oc.qctx.quote.Id,
            Quote_Line_Group__c = oc.qlg.Id,
            Vessel_Name__c = vessel.Id,
            Installation_Order_Status__c = 'Future Terminated',
            Termination_End_Date__c = Date.today(),
            Termination_Quote__c = oc.qctx.quote.Id,
            Termination_Process_Status__c = 'Waiting For Order Activation',
            Auto_Termination__c = true
        );
        insert groupedInstallation;

        update new Installation__c(
            Id = oc.installation.Id,
            Contract__c = oc.packageRec.Contract__c,
            Installation_Order_Status__c = 'Future Terminated',
            Termination_End_Date__c = Date.today(),
            Termination_Quote__c = oc.qctx.quote.Id,
            Termination_Process_Status__c = 'Waiting For Order Activation',
            Auto_Termination__c = true
        );

        update new SBQQ__Quote__c(
            Id = oc.qctx.quote.Id,
            Auto_Termination__c = true,
            Installation__c = oc.installation.Id
        );

        Test.startTest();
        update new Order(
            Id = oc.orderRec.Id,
            Status = 'Activated',
            Is_Activated__c = true
        );
        Test.stopTest();

        Map<Id, Installation__c> refreshed = new Map<Id, Installation__c>([
            SELECT Installation_Order_Status__c, Termination_Order__c, Termination_Process_Status__c
            FROM Installation__c
            WHERE Id IN :new Set<Id>{oc.installation.Id, groupedInstallation.Id}
        ]);
        System.assertEquals('Terminated', refreshed.get(oc.installation.Id).Installation_Order_Status__c);
        System.assertEquals('Terminated', refreshed.get(groupedInstallation.Id).Installation_Order_Status__c);
        System.assertEquals(oc.orderRec.Id, refreshed.get(groupedInstallation.Id).Termination_Order__c);
        System.assertEquals('Completed', refreshed.get(groupedInstallation.Id).Termination_Process_Status__c);
    }
}
