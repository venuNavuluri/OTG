@IsTest
public class InstallationProductUpdateServiceTest {

    @IsTest
    static void testProcessOrdersWithEmptyInput() {
        Test.startTest();
        Map<Id, InstallationProductUpdateService.PackageGroup> resultNull =
            InstallationProductUpdateService.processOrders(null);
        Map<Id, InstallationProductUpdateService.PackageGroup> resultEmpty =
            InstallationProductUpdateService.processOrders(new Set<Id>());
        Test.stopTest();

        System.assertEquals(0, resultNull.size(), 'Null order set should return empty result');
        System.assertEquals(0, resultEmpty.size(), 'Empty order set should return empty result');
    }

    @IsTest
    static void testCalculateProratedAmount() {
        Decimal netPrice = 1200;
        Date subscriptionStart = Date.newInstance(2024, 1, 1);
        Date subscriptionEnd = Date.newInstance(2024, 12, 31);
        Date overlapStart = Date.newInstance(2024, 4, 1);
        Date overlapEnd = Date.newInstance(2024, 6, 30);

        Test.startTest();
        Decimal prorated = InstallationProductUpdateService.calculateProratedAmount(
            netPrice,
            subscriptionStart,
            subscriptionEnd,
            overlapStart,
            overlapEnd
        );
        Test.stopTest();

        System.assertNotEquals(null, prorated, 'Prorated amount should be calculated');
        System.assert(prorated > 0, 'Prorated amount should be positive for valid overlap');
    }

    @IsTest
    static void testCreateInstallationLinesFromSubscriptionsWithoutSubscriptions() {
        Package__c pkg = new Package__c(
            Name = 'Package - No Subs',
            Product_Change_Type__c = 'Upgrade',
            CurrencyIsoCode = 'USD'
        );
        insert pkg;

        InstallationProductUpdateService.PackageGroup pkgGroup = new InstallationProductUpdateService.PackageGroup(pkg);
        pkgGroup.installations = new List<Installation__c>();
        pkgGroup.subscriptions = new List<SBQQ__Subscription__c>();

        Map<Id, InstallationProductUpdateService.PackageGroup> packageGroups =
            new Map<Id, InstallationProductUpdateService.PackageGroup>{
                pkg.Id => pkgGroup
            };

        Test.startTest();
        List<Installation_Line__c> result =
            InstallationProductUpdateService.createInstallationLinesFromSubscriptions(packageGroups);
        Test.stopTest();

        System.assertEquals(0, result.size(), 'No lines should be created without subscriptions');
    }

    @IsTest
    static void testProcessOrdersAndSalesOrderUpdates() {
        TestDataFactory_OTG.OrderContext ctx =
            TestDataFactory_OTG.buildOrderContext('Americas', 'Amendment', 'Draft', false, false);

        Contract contractRec = [
            SELECT Id, Status, CurrencyIsoCode
            FROM Contract
            WHERE Id = :ctx.packageRec.Contract__c
        ];
        update new Contract(
            Id = contractRec.Id,
            Status = 'Activated'
        );

        Account invoiceAccount = TestDataFactory_OTG.createInvoiceAccount(
            UserInfo.getUserId(),
            ctx.qctx.country.Id,
            ctx.qctx.b2bAccount.Id
        );

        update new Package__c(
            Id = ctx.packageRec.Id,
            Product_Change_Type__c = 'Products Added & Removed',
            Quote__c = ctx.qctx.quote.Id,
            Quote_Line_Group__c = ctx.qlg.Id,
            Order__c = ctx.orderRec.Id
        );

        Date instStart = Date.today().addMonths(-6);
        Date instEnd = Date.today().addMonths(6);
        update new Installation__c(
            Id = ctx.installation.Id,
            Contract__c = contractRec.Id,
            Order__c = ctx.orderRec.Id,
            Quote__c = ctx.qctx.quote.Id,
            Quote_Line_Group__c = ctx.qlg.Id,
            Installation_Start_Date__c = instStart,
            Installation_End_Date__c = instEnd,
            Installation_Order_Status__c = 'Active',
            Change_Package_Status__c = 'Completed',
            CurrencyIsoCode = contractRec.CurrencyIsoCode
        );

        ctx.installation = [
            SELECT Id, Contract__c, CurrencyIsoCode, Package__c
            FROM Installation__c
            WHERE Id = :ctx.installation.Id
        ];

        update new SBQQ__Quote__c(
            Id = ctx.qctx.quote.Id,
            SBQQ__MasterContract__c = contractRec.Id
        );

        Map<String, Object> billedSOFields = new Map<String, Object>{
            'Installation__c'    => ctx.installation.Id,
            'Contract__c'        => contractRec.Id,
            'Start_Date__c'      => Date.today().addMonths(-2),
            'End_Date__c'        => Date.today().addMonths(-1),
            'Status__c'          => 'Billed',
            'Invoice_Account__c' => invoiceAccount.Id,
            'CurrencyIsoCode'    => contractRec.CurrencyIsoCode
        };
        Sales_Order__c billedSO = (Sales_Order__c)TestDataFactory.createSObject(
            'Sales_Order__c',
            billedSOFields,
            true
        );

        Map<String, Object> unbilledSOFields = new Map<String, Object>{
            'Installation__c'    => ctx.installation.Id,
            'Contract__c'        => contractRec.Id,
            'Start_Date__c'      => Date.today(),
            'End_Date__c'        => Date.today().addMonths(2),
            'Status__c'          => 'Unbilled',
            'Invoice_Account__c' => invoiceAccount.Id,
            'CurrencyIsoCode'    => contractRec.CurrencyIsoCode
        };
        Sales_Order__c unbilledSO = (Sales_Order__c)TestDataFactory.createSObject(
            'Sales_Order__c',
            unbilledSOFields,
            true
        );

        List<OrderItem> orderItems = [
            SELECT Id
            FROM OrderItem
            WHERE OrderId = :ctx.orderRec.Id
            ORDER BY CreatedDate
        ];
        List<OrderItem> orderItemsToInsert = new List<OrderItem>();
        while (orderItems.size() + orderItemsToInsert.size() < 2) {
            orderItemsToInsert.add(new OrderItem(
                OrderId = ctx.orderRec.Id,
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
            new OrderItem(
                Id = newOrderItem.Id,
                SBQQ__ContractAction__c = 'New',
                SBQQ__QuoteLine__c = newQuoteLine.Id
            ),
            new OrderItem(
                Id = cancelOrderItem.Id,
                SBQQ__ContractAction__c = 'Cancel',
                SBQQ__QuoteLine__c = cancelQuoteLine.Id
            )
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

        Map<Id, SBQQ__Subscription__c> refreshedSubs = new Map<Id, SBQQ__Subscription__c>(
            [
                SELECT Id,
                       SBQQ__Product__c,
                       SBQQ__Product__r.Name,
                       SBQQ__NetPrice__c,
                       SBQQ__Quantity__c,
                       SBQQ__StartDate__c,
                       SBQQ__EndDate__c,
                       SBQQ__SegmentStartDate__c,
                       SBQQ__SegmentEndDate__c,
                       CurrencyIsoCode,
                       SBQQ__OrderProduct__c,
                       SBQQ__OrderProduct__r.SBQQ__ContractAction__c,
                       SBQQ__QuoteLine__c
                FROM SBQQ__Subscription__c
                WHERE Id IN :new List<Id>{ newSub.Id, cancelSub.Id }
            ]
        );
        newSub = refreshedSubs.get(newSub.Id);
        cancelSub = refreshedSubs.get(cancelSub.Id);

        update new List<OrderItem>{
            new OrderItem(Id = newOrderItem.Id, SBQQ__Subscription__c = newSub.Id),
            new OrderItem(Id = cancelOrderItem.Id, SBQQ__Subscription__c = cancelSub.Id)
        };

        update new Order(Id = ctx.orderRec.Id, Status = 'Activated', Is_Activated__c = true);
        ctx.orderRec = [
            SELECT Id, EffectiveDate
            FROM Order
            WHERE Id = :ctx.orderRec.Id
        ];

        Map<Id, InstallationProductUpdateService.PackageGroup> packageGroups;
        List<Installation_Line__c> createdLines;
        Test.startTest();
        packageGroups = InstallationProductUpdateService.processOrders(new Set<Id>{ ctx.orderRec.Id });
        InstallationProductUpdateService.PackageGroup pkgGroup = packageGroups.get(ctx.packageRec.Id);
        System.assertNotEquals(null, pkgGroup, 'Expected package group for test package');
        if (pkgGroup.subscriptions == null) {
            pkgGroup.subscriptions = new List<SBQQ__Subscription__c>();
        }
        pkgGroup.subscriptions.clear();
        pkgGroup.subscriptions.add(newSub);
        pkgGroup.subscriptions.add(cancelSub);

        Boolean hasInstall = false;
        for (Installation__c inst : pkgGroup.installations) {
            if (inst.Id == ctx.installation.Id) {
                hasInstall = true;
                break;
            }
        }
        if (!hasInstall) {
            pkgGroup.installations.add(ctx.installation);
        }
        createdLines = InstallationProductUpdateService.createInstallationLinesFromSubscriptions(packageGroups);
        Test.stopTest();

        System.assert(!packageGroups.isEmpty(), 'Expected package groups to be returned');
        System.assertEquals(2, createdLines.size(), 'Expected two installation lines to be created');

        List<Sales_Order__c> resultingOrders = [
            SELECT Id, Credit_Note__c, Status__c, Installation__c
            FROM Sales_Order__c
            WHERE Installation__c = :ctx.installation.Id
        ];

        List<Sales_Order_Item__c> soItems = [
            SELECT Sales_Order__c, Amount__c
            FROM Sales_Order_Item__c
            WHERE Sales_Order__c IN :new Map<Id, Sales_Order__c>(resultingOrders).keySet()
        ];

        Set<Id> unbilledOrderIds = new Set<Id>();
        for (Sales_Order__c order : resultingOrders) {
            if (order.Status__c == 'Unbilled' && !order.Credit_Note__c) {
                unbilledOrderIds.add(order.Id);
            }
        }
        System.assert(!unbilledOrderIds.isEmpty(), 'Expected at least one standard unbilled sales order');

        Boolean unbilledHasItem = false;
        Boolean hasNegativeItem = false;
        for (Sales_Order_Item__c item : soItems) {
            if (unbilledOrderIds.contains(item.Sales_Order__c)) {
                unbilledHasItem = true;
            }
            if (item.Amount__c < 0) {
                hasNegativeItem = true;
            }
        }
        System.assert(unbilledHasItem, 'Expected unbilled sales order to receive prorated items');
        System.assert(hasNegativeItem, 'Expected at least one negative (credit) sales order item to be created');

        Map<Id, List<Installation__c>> grouped =
            InstallationProductUpdateService.groupInstallationsByPackage(
                new List<Installation__c>{
                    [SELECT Id, Package__c FROM Installation__c WHERE Id = :ctx.installation.Id]
                }
            );
        System.assertEquals(1, grouped.get(ctx.installation.Package__c).size(),
            'Installation should group under its package');

        List<Sales_Order__c> fetched =
            InstallationProductUpdateService.fetchFilteredSalesOrdersByContractAndPeriod(
                new Set<Id>{ ctx.installation.Id },
                new Set<Id>{ contractRec.Id },
                new List<Order>()
            );
        System.assert(fetched.size() > 0, 'Fetch helper should return at least one sales order');

        Map<Id, List<Sales_Order__c>> indexed =
            InstallationProductUpdateService.indexSalesOrdersByInstallation(fetched);
        System.assert(indexed.containsKey(ctx.installation.Id),
            'Index helper should collect sales orders by installation');
    }

    @IsTest
    static void testProcessSalesOrdersCreatesCreditNoteForBilledOrder() {
        TestDataFactory_OTG.OrderContext ctx =
            TestDataFactory_OTG.buildOrderContext('Americas', 'Amendment', 'Draft', false, false);

        Contract contractRec = [
            SELECT Id, Status, CurrencyIsoCode
            FROM Contract
            WHERE Id = :ctx.packageRec.Contract__c
        ];
        update new Contract(
            Id = contractRec.Id,
            Status = 'Activated'
        );

        Account invoiceAccount = TestDataFactory_OTG.createInvoiceAccount(
            UserInfo.getUserId(),
            ctx.qctx.country.Id,
            ctx.qctx.b2bAccount.Id
        );

        update new Package__c(
            Id = ctx.packageRec.Id,
            Quote__c = ctx.qctx.quote.Id,
            Quote_Line_Group__c = ctx.qlg.Id,
            Order__c = ctx.orderRec.Id,
            Product_Change_Type__c = 'Products Removed'
        );

        update new Installation__c(
            Id = ctx.installation.Id,
            Contract__c = contractRec.Id,
            Order__c = ctx.orderRec.Id,
            Quote__c = ctx.qctx.quote.Id,
            Quote_Line_Group__c = ctx.qlg.Id,
            Installation_Start_Date__c = Date.today().addMonths(-4),
            Installation_End_Date__c = Date.today().addMonths(4),
            Installation_Order_Status__c = 'Active',
            Change_Package_Status__c = 'Completed',
            CurrencyIsoCode = contractRec.CurrencyIsoCode
        );

        Sales_Order__c billedSO = (Sales_Order__c)TestDataFactory.createSObject(
            'Sales_Order__c',
            new Map<String, Object>{
                'Installation__c'    => ctx.installation.Id,
                'Contract__c'        => contractRec.Id,
                'Start_Date__c'      => Date.today().addMonths(-1),
                'End_Date__c'        => Date.today().addMonths(2),
                'Status__c'          => 'Billed',
                'Invoice_Account__c' => invoiceAccount.Id,
                'CurrencyIsoCode'    => contractRec.CurrencyIsoCode
            },
            true
        );

        Installation_Line__c cancelLine = new Installation_Line__c(
            Name = 'Cancel Line',
            Installation__c = ctx.installation.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addMonths(2),
            Net_Total__c = -250,
            CurrencyIsoCode = contractRec.CurrencyIsoCode
        );
        insert cancelLine;

        Test.startTest();
        InstallationProductUpdateService.processOrders(new Set<Id>{ ctx.orderRec.Id });
        InstallationProductUpdateService.processSalesOrders(new List<Installation_Line__c>{ cancelLine });
        Test.stopTest();

        List<Sales_Order__c> creditOrders = [
            SELECT Id, Credit_Note__c, Status__c, Installation__c
            FROM Sales_Order__c
            WHERE Installation__c = :ctx.installation.Id
              AND Id != :billedSO.Id
        ];
        System.assert(!creditOrders.isEmpty(), 'Expected a credit note sales order to be created');

        Boolean foundCredit = false;
        for (Sales_Order__c credit : creditOrders) {
            if (credit.Credit_Note__c && credit.Status__c == 'Unbilled') {
                foundCredit = true;
                break;
            }
        }
        System.assert(foundCredit, 'Expected the new sales order to be marked as a credit note');

        List<Sales_Order_Item__c> creditItems = [
            SELECT Sales_Order__c, Amount__c
            FROM Sales_Order_Item__c
            WHERE Sales_Order__c IN :new Map<Id, Sales_Order__c>(creditOrders).keySet()
        ];
        Boolean hasNegativeAmount = false;
        for (Sales_Order_Item__c item : creditItems) {
            if (item.Amount__c < 0) {
                hasNegativeAmount = true;
                break;
            }
        }
        System.assert(hasNegativeAmount, 'Expected the credit sales order to contain a negative amount item');
    }
}