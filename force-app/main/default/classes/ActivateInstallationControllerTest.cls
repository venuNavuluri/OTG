@IsTest
private class ActivateInstallationControllerTest {

    @TestSetup
    static void setupOrgDefaults() {
        TestDataFactory_OTG.enableOrgVRConfig();
        TestDataFactory_OTG.primeDefaultOwnerAllRegions(UserInfo.getUserId());

        VRConfiguration__c config = VRConfiguration__c.getOrgDefaults();
        if (config == null) {
            config = new VRConfiguration__c();
        }
       // config.ByPass_Account_Triggers__c = true;
       // config.ByPass_Contract_Triggers__c = true;
       // config.ByPass_Opportunity_Triggers__c = true;
       // config.ByPass_Flow__c = true;
        upsert config;
    }

    @IsTest
    static void testActivateInstallationGeneratesLinesAndOrders() {
        TestDataFactory_OTG.OrderContext ctx =
            TestDataFactory_OTG.buildOrderContext('Americas', 'Amendment', 'Draft', true, false);

        Contract contractRec = [
            SELECT Id, CurrencyIsoCode
            FROM Contract
            WHERE Id = :ctx.packageRec.Contract__c
        ];
        update new Contract(
            Id = contractRec.Id,
            Status = 'Activated',
            StartDate = Date.today().addMonths(-1),
            EndDate = Date.today().addMonths(11),
            Billing_Frequency__c = 'Monthly'
        );

        Order orderRec = [
            SELECT Id, Pricebook2Id
            FROM Order
            WHERE Id = :ctx.orderRec.Id
        ];
        update new Order(
            Id = orderRec.Id,
            Status = 'Activated',
            EffectiveDate = Date.today(),
            Is_Activated__c = true
        );

        Installation__c inst = [
            SELECT Id, Installation_Start_Date__c
            FROM Installation__c
            WHERE Id = :ctx.installation.Id
        ];

        update new Installation__c(
            Id = inst.Id,
            Contract__c = contractRec.Id,
            Quote__c = ctx.qctx.quote.Id,
            Quote_Line_Group__c = ctx.qlg.Id,
            Order__c = orderRec.Id,
            Installation_Start_Date__c = Date.today().addMonths(-2),
            Installation_End_Date__c = Date.today().addMonths(10),
            DeleteInstallationLinesAndSOs__c = true,
            Installation_Order_Status__c = 'Pending Implementation'
        );

        OrderItem oi = [
            SELECT Id
            FROM OrderItem
            WHERE OrderId = :orderRec.Id
            LIMIT 1
        ];

        SBQQ__QuoteLine__c ql = TestDataFactory_OTG.createQuoteLine(
            ctx.qctx.quote.Id,
            ctx.qlg.Id,
            ctx.qctx.pbe.Id,
            1,
            null,
            120,
            Date.today(),
            Date.today().addMonths(6),
            null
        );

        update new OrderItem(
            Id = oi.Id,
            SBQQ__QuoteLine__c = ql.Id
        );

        SBQQ__Subscription__c sub = new SBQQ__Subscription__c(
            SBQQ__Product__c = ctx.qctx.product.Id,
            SBQQ__SubscriptionStartDate__c = Date.today(),
            SBQQ__SubscriptionEndDate__c = Date.today().addMonths(6),
            SBQQ__NetPrice__c = 120,
            SBQQ__Quantity__c = 1,
            CurrencyIsoCode = contractRec.CurrencyIsoCode,
            SBQQ__OrderProduct__c = oi.Id,
            SBQQ__QuoteLine__c = ql.Id
        );
        insert sub;

        Installation_Line__c obsoleteLine = new Installation_Line__c(
            Name = 'Obsolete',
            Installation__c = inst.Id,
            Start_Date__c = Date.today().addMonths(-3),
            End_Date__c = Date.today().addMonths(-2),
            Net_Total__c = 50,
            CurrencyIsoCode = contractRec.CurrencyIsoCode
        );
        insert obsoleteLine;

        Sales_Order__c obsoleteSO = new Sales_Order__c(
            Contract__c = contractRec.Id,
            Installation__c = inst.Id,
            Start_Date__c = Date.today().addMonths(-3),
            End_Date__c = Date.today().addMonths(-2),
            Status__c = 'Unbilled',
            CurrencyIsoCode = contractRec.CurrencyIsoCode
        );
        insert obsoleteSO;

        Date activationStart = Date.today();

        Test.startTest();
        String result = ActivateInstallationController.activateInstallation(inst.Id, activationStart);
        Test.stopTest();

        System.assertEquals('SUCCESS', result, 'Controller should return SUCCESS');

        Installation__c refreshedInst = [
            SELECT Installation_Order_Status__c, Installation_Start_Date__c, Installation_End_Date__c
            FROM Installation__c
            WHERE Id = :inst.Id
        ];
        System.assertEquals('Active', refreshedInst.Installation_Order_Status__c, 'Installation should be active');
        System.assertEquals(activationStart, refreshedInst.Installation_Start_Date__c, 'Start date should be updated');

        System.assertEquals(0, [SELECT COUNT() FROM Installation_Line__c WHERE Id = :obsoleteLine.Id],
            'Legacy installation lines should be removed');
        System.assertEquals(0, [SELECT COUNT() FROM Sales_Order__c WHERE Id = :obsoleteSO.Id],
            'Legacy sales orders should be removed');

        Integer newLineCount = [
            SELECT COUNT()
            FROM Installation_Line__c
            WHERE Installation__c = :inst.Id
        ];
        System.assert(newLineCount > 0, 'New installation lines should be created');

        Integer newSOCount = [
            SELECT COUNT()
            FROM Sales_Order__c
            WHERE Installation__c = :inst.Id
        ];
        System.assert(newSOCount > 0, 'Sales orders should be generated');
    }

    @IsTest
    static void testActivateInstallationWithoutSubscriptions() {
        TestDataFactory_OTG.OrderContext ctx =
            TestDataFactory_OTG.buildOrderContext('Americas', 'Amendment', 'Draft', true, false);

        Contract contractRec = [
            SELECT Id, CurrencyIsoCode
            FROM Contract
            WHERE Id = :ctx.packageRec.Contract__c
        ];
        update new Contract(
            Id = contractRec.Id,
            Status = 'Activated',
            StartDate = Date.today().addMonths(-2),
            EndDate = Date.today().addMonths(10),
            Billing_Frequency__c = 'Quarterly'
        );

        Order orderRec = [
            SELECT Id
            FROM Order
            WHERE Id = :ctx.orderRec.Id
        ];
        update new Order(
            Id = orderRec.Id,
            Status = 'Activated',
            EffectiveDate = Date.today(),
            Is_Activated__c = true
        );

        Installation__c inst = [
            SELECT Id
            FROM Installation__c
            WHERE Id = :ctx.installation.Id
        ];

        update new Installation__c(
            Id = inst.Id,
            Contract__c = contractRec.Id,
            Quote__c = ctx.qctx.quote.Id,
            Quote_Line_Group__c = ctx.qlg.Id,
            Order__c = orderRec.Id,
            Installation_Start_Date__c = Date.today().addMonths(-4),
            Installation_End_Date__c = Date.today().addMonths(8),
            DeleteInstallationLinesAndSOs__c = true,
            Installation_Order_Status__c = 'Active'
        );

        Installation_Line__c obsoleteLine = new Installation_Line__c(
            Name = 'WillDelete',
            Installation__c = inst.Id,
            Start_Date__c = Date.today().addMonths(-5),
            End_Date__c = Date.today().addMonths(-4),
            Net_Total__c = 10,
            CurrencyIsoCode = contractRec.CurrencyIsoCode
        );
        insert obsoleteLine;

        Date activationStart = Date.today();

        Test.startTest();
        String result = ActivateInstallationController.activateInstallation(inst.Id, activationStart);
        Test.stopTest();

        System.assertEquals('SUCCESS', result, 'Controller should return SUCCESS even when no subscriptions are found');

        Installation__c refreshedInst = [
            SELECT Installation_Order_Status__c, Installation_Start_Date__c
            FROM Installation__c
            WHERE Id = :inst.Id
        ];
        System.assertEquals('Active', refreshedInst.Installation_Order_Status__c, 'Installation should activate');
        System.assertEquals(activationStart, refreshedInst.Installation_Start_Date__c);

        System.assertEquals(0, [SELECT COUNT() FROM Installation_Line__c WHERE Id = :obsoleteLine.Id],
            'Existing lines should be cleared');

        Integer newLineCount = [
            SELECT COUNT()
            FROM Installation_Line__c
            WHERE Installation__c = :inst.Id
        ];
        System.assertEquals(0, newLineCount, 'No new installation lines expected without subscriptions');
    }
}