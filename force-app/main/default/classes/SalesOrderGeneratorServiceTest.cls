@IsTest
private class SalesOrderGeneratorServiceTest {

    @TestSetup
    static void setupOrgDefaults() {
        TestDataFactory_OTG.enableOrgVRConfig();
        TestDataFactory_OTG.primeDefaultOwnerAllRegions(UserInfo.getUserId());
        VRConfiguration__c config = VRConfiguration__c.getOrgDefaults();
        if (config == null) {
            config = new VRConfiguration__c();
        }
        //config.ByPass_Account_Triggers__c = true;
        //config.ByPass_Contract_Triggers__c = true;
        //config.ByPass_Flow__c = true;
        //config.ByPass_Opportunity_Triggers__c = true;
        upsert config;
    }

    private class InstallationSetup {
        Id installationId;
        Date expectedAnchorDate;
    }

    private static InstallationSetup createInstallation(Boolean withOrderActivation, String billingFrequency) {


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
            StartDate = Date.today().addMonths(-6),
            EndDate = Date.today().addMonths(6),
            Billing_Frequency__c = billingFrequency
        );

        Order orderRecord = [
            SELECT Id, Pricebook2Id
            FROM Order
            WHERE Id = :ctx.orderRec.Id
        ];
        DateTime activationDateTime = withOrderActivation
            ? DateTime.newInstance(Date.today().addDays(-5), Time.newInstance(0, 0, 0, 0))
            : null;
        update new Installation__c(
            Id = ctx.installation.Id,
            Contract__c = contractRec.Id,
            Order__c = orderRecord.Id,
            Quote__c = ctx.qctx.quote.Id,
            Quote_Line_Group__c = ctx.qlg.Id,
            Installation_Start_Date__c = Date.today().addMonths(-4),
            Installation_End_Date__c = Date.today().addMonths(4),
            Installation_Order_Status__c = 'Active',
            Change_Package_Status__c = 'Completed',
            CurrencyIsoCode = contractRec.CurrencyIsoCode
        );

        List<OrderItem> orderItems = [
            SELECT Id
            FROM OrderItem
            WHERE OrderId = :orderRecord.Id
            ORDER BY CreatedDate
        ];
        List<OrderItem> orderItemsToInsert = new List<OrderItem>();
        while (orderItems.size() + orderItemsToInsert.size() < 2) {
            orderItemsToInsert.add(new OrderItem(
                OrderId = orderRecord.Id,
                PricebookEntryId = ctx.qctx.pbe.Id,
                Quantity = 1,
                UnitPrice = orderItemsToInsert.isEmpty() ? 100 : 200
            ));
        }
        if (!orderItemsToInsert.isEmpty()) {
            insert orderItemsToInsert;
            orderItems.addAll(orderItemsToInsert);
        }

        OrderItem newOrderItem = orderItems[0];
        OrderItem cancelOrderItem = orderItems[1];

        SBQQ__QuoteLine__c newQuoteLine = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c   = ctx.qctx.quote.Id,
            SBQQ__Product__c = ctx.qctx.product.Id,
            SBQQ__Group__c   = ctx.qlg.Id,
            SBQQ__ListPrice__c = 100,
            SBQQ__NetPrice__c  = 100,
            SBQQ__Quantity__c  = 1
        );

        SBQQ__QuoteLine__c cancelQuoteLine = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c   = ctx.qctx.quote.Id,
            SBQQ__Product__c = ctx.qctx.product.Id,
            SBQQ__Group__c   = ctx.qlg.Id,
            SBQQ__ListPrice__c = 200,
            SBQQ__NetPrice__c  = 200,
            SBQQ__Quantity__c  = 1
        );
        insert new List<SBQQ__QuoteLine__c>{ newQuoteLine, cancelQuoteLine };

        update new List<OrderItem>{
            new OrderItem(Id = newOrderItem.Id, SBQQ__ContractAction__c = 'New', SBQQ__QuoteLine__c = newQuoteLine.Id),
            new OrderItem(Id = cancelOrderItem.Id, SBQQ__ContractAction__c = 'Cancel', SBQQ__QuoteLine__c = cancelQuoteLine.Id)
        };

        SBQQ__Subscription__c newSub = new SBQQ__Subscription__c(
            Package__c = ctx.packageRec.Id,
            SBQQ__Product__c = ctx.qctx.product.Id,
            SBQQ__SubscriptionStartDate__c = Date.today(),
            SBQQ__SubscriptionEndDate__c = Date.today().addMonths(6),
            SBQQ__NetPrice__c = 100,
            SBQQ__Quantity__c = 1,
            CurrencyIsoCode = contractRec.CurrencyIsoCode,
            SBQQ__OrderProduct__c = newOrderItem.Id,
            SBQQ__QuoteLine__c = newQuoteLine.Id
        );

        SBQQ__Subscription__c cancelSub = new SBQQ__Subscription__c(
            Package__c = ctx.packageRec.Id,
            SBQQ__Product__c = ctx.qctx.product.Id,
            SBQQ__SubscriptionStartDate__c = Date.today().addMonths(-2),
            SBQQ__SubscriptionEndDate__c = Date.today().addMonths(2),
            SBQQ__NetPrice__c = 200,
            SBQQ__Quantity__c = 1,
            CurrencyIsoCode = contractRec.CurrencyIsoCode,
            SBQQ__OrderProduct__c = cancelOrderItem.Id,
            SBQQ__QuoteLine__c = cancelQuoteLine.Id
        );
        insert new List<SBQQ__Subscription__c>{ newSub, cancelSub };

        update new List<OrderItem>{
            new OrderItem(Id = newOrderItem.Id, SBQQ__Subscription__c = newSub.Id),
            new OrderItem(Id = cancelOrderItem.Id, SBQQ__Subscription__c = cancelSub.Id)
        };

        if (activationDateTime != null) {
            update new Order(
                Id = orderRecord.Id,
                Status = 'Activated',
                EffectiveDate = Date.today(),
                Pricebook2Id = orderRecord.Pricebook2Id,
                Is_Activated__c = true,
                ActivatedDate = activationDateTime
            );
        } else {
            update new Order(
                Id = orderRecord.Id,
                Status = 'Activated',
                EffectiveDate = Date.today(),
                Pricebook2Id = orderRecord.Pricebook2Id,
                Is_Activated__c = true
            );
        }

        Date alignedStart = Date.newInstance(Date.today().year(), Date.today().month(), 1);
        Date alignedEnd = alignedStart.addMonths(1).addDays(-1);
        Installation_Line__c alignedLine = new Installation_Line__c(
            Name = 'Aligned Line',
            Installation__c = ctx.installation.Id,
            Start_Date__c = alignedStart,
            End_Date__c = alignedEnd,
            Net_Total__c = 200,
            CurrencyIsoCode = contractRec.CurrencyIsoCode,
            Subscription__c = newSub.Id
        );

        Installation_Line__c irregularLine = new Installation_Line__c(
            Name = 'Irregular Line',
            Installation__c = ctx.installation.Id,
            Start_Date__c = Date.today().addDays(-10),
            End_Date__c = Date.today().addDays(50),
            Net_Total__c = 150,
            CurrencyIsoCode = contractRec.CurrencyIsoCode,
            Subscription__c = cancelSub.Id
        );
        insert new List<Installation_Line__c>{ alignedLine, irregularLine };

        Order refreshedOrder = [
            SELECT Id, ActivatedDate
            FROM Order
            WHERE Id = :orderRecord.Id
            LIMIT 1
        ];

        InstallationSetup setup = new InstallationSetup();
        setup.installationId = ctx.installation.Id;
        setup.expectedAnchorDate =
            withOrderActivation && refreshedOrder.ActivatedDate != null
                ? Date.newInstance(
                    refreshedOrder.ActivatedDate.year(),
                    refreshedOrder.ActivatedDate.month(),
                    refreshedOrder.ActivatedDate.day()
                )
                : null;
        return setup;
    }

    private static Installation__c createInstallationWithoutLines() {
        Account acct = (Account)TestDataFactory.createSObject('Account', new Map<String, Object>{
            'Name' => 'SO No Line Acc'
        }, true);

        Contract contractRec = TestDataFactory_OTG.createContractBasic(
            acct.Id,
            'USD',
            Date.today().addMonths(-3),
            12,
            Date.today().addMonths(9)
        );
        update new Contract(Id = contractRec.Id, Status = 'Activated', Billing_Frequency__c = 'Monthly');

        Installation__c inst = new Installation__c(
            Contract__c = contractRec.Id,
            Installation_Start_Date__c = Date.today().addMonths(-3),
            Installation_End_Date__c = Date.today().addMonths(9),
            Installation_Order_Status__c = 'Active',
            CurrencyIsoCode = 'USD'
        );
        insert inst;
        return inst;
    }

    @IsTest
    static void testGenerateSalesOrdersCreatesOrdersAndItems() {
        InstallationSetup standardSetup = createInstallation(false, 'Quarterly');

        Test.startTest();
        SalesOrderGeneratorService.generateSalesOrders(
            new List<Installation__c>{ new Installation__c(Id = standardSetup.installationId) },
            false,
            false
        );
        Test.stopTest();

        List<Sales_Order__c> standardOrders = [
            SELECT Id, Start_Date__c, End_Date__c
            FROM Sales_Order__c
            WHERE Installation__c = :standardSetup.installationId
        ];
        System.assert(!standardOrders.isEmpty(), 'Expected sales orders for standard installation');

        List<Sales_Order_Item__c> standardItems = [
            SELECT Id
            FROM Sales_Order_Item__c
            WHERE Sales_Order__c IN :standardOrders
        ];
        System.assert(!standardItems.isEmpty(), 'Expected sales order items for standard installation');
    }

    @IsTest
    static void testGenerateSalesOrdersAnchorsToActivationDate() {
        InstallationSetup packageSetup = createInstallation(true, 'Monthly');

        Test.startTest();
        SalesOrderGeneratorService.generateSalesOrders(
            new List<Installation__c>{ new Installation__c(Id = packageSetup.installationId) },
            true,
            true
        );
        Test.stopTest();

        List<Sales_Order__c> packageOrders = [
            SELECT Id, Start_Date__c
            FROM Sales_Order__c
            WHERE Installation__c = :packageSetup.installationId
        ];
        System.assert(!packageOrders.isEmpty(), 'Expected sales orders for package change installation');

        if (packageSetup.expectedAnchorDate != null) {
            Boolean anchorMatched = false;
            for (Sales_Order__c so : packageOrders) {
                if (so.Start_Date__c == packageSetup.expectedAnchorDate) {
                    anchorMatched = true;
                    break;
                }
            }
            System.assert(anchorMatched, 'Expected package change orders to anchor to activation date');
        }
    }

    @IsTest
    static void testGenerateSalesOrdersWithNoLinesDoesNothing() {
        Installation__c inst = createInstallationWithoutLines();

        Test.startTest();
        SalesOrderGeneratorService.generateSalesOrders(
            new List<Installation__c>{ new Installation__c(Id = inst.Id) },
            false,
            false
        );
        Test.stopTest();

        Integer orderCount = [
            SELECT COUNT()
            FROM Sales_Order__c
            WHERE Installation__c = :inst.Id
        ];
        System.assertEquals(0, orderCount, 'No orders should be generated when installation has no lines');
    }
}