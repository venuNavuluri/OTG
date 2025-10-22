@IsTest
private class InstallationsRenewalServiceTest {

    private static TestDataFactory_OTG.OrderContext buildRenewalContext() {
        TestDataFactory_OTG.OrderContext ctx =
            TestDataFactory_OTG.buildOrderContext('Americas', 'Renewal', 'Draft', false, false);

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
            Billing_Frequency__c = 'Monthly'
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
            Product_Change_Type__c = 'Products Added & Removed'
        );

        update new Installation__c(
            Id = ctx.installation.Id,
            Contract__c = contractRec.Id,
            Order__c = ctx.orderRec.Id,
            Quote__c = ctx.qctx.quote.Id,
            Quote_Line_Group__c = ctx.qlg.Id,
            Installation_Start_Date__c = Date.today().addMonths(-6),
            Installation_End_Date__c = Date.today().addMonths(6),
            Installation_Order_Status__c = 'Active',
            Change_Package_Status__c = 'Completed',
            CurrencyIsoCode = contractRec.CurrencyIsoCode
        );

        update new SBQQ__Quote__c(
            Id = ctx.qctx.quote.Id,
            SBQQ__MasterContract__c = contractRec.Id
        );

        update new Order(
            Id = ctx.orderRec.Id,
            Type = 'Renewal',
            Is_Activated__c = true
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

        return ctx;
    }

    @IsTest
    static void testProcessRenewalInstallationsCreatesLinesAndOrders() {
        TestDataFactory_OTG.OrderContext ctx = buildRenewalContext();

        Installation__c inst = [
            SELECT Id,
                   Contract__c,
                   Contract__r.StartDate,
                   Quote_Line_Group__c,
                   Order__c,
                   Installation_Start_Date__c,
                   Installation_End_Date__c,
                   Invoice_Account__c,
                   CurrencyIsoCode
            FROM Installation__c
            WHERE Id = :ctx.installation.Id
        ];

        Test.startTest();
        InstallationsRenewalService.processRenewalInstallations(new List<Installation__c>{ inst });
        Test.stopTest();

        Integer lineCount = [
            SELECT COUNT()
            FROM Installation_Line__c
            WHERE Installation__c = :ctx.installation.Id
        ];
        System.assert(lineCount > 0, 'Expected installation lines to be created for renewal');

        Integer soCount = [
            SELECT COUNT()
            FROM Sales_Order__c
            WHERE Installation__c = :ctx.installation.Id
        ];
        System.assert(soCount > 0, 'Expected sales orders to be generated for renewal installation');
    }

    @IsTest
    static void testProcessRenewalInstallationsWithoutSubscriptions() {
        Account acct = (Account)TestDataFactory.createSObject('Account', new Map<String, Object>{
            'Name' => 'No Subs Account'
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

        Installation__c instRecord = [
            SELECT Id,
                   Contract__c,
                   Contract__r.StartDate,
                   Quote_Line_Group__c,
                   Order__c,
                   Installation_Start_Date__c,
                   Installation_End_Date__c,
                   Invoice_Account__c,
                   CurrencyIsoCode
            FROM Installation__c
            WHERE Id = :inst.Id
        ];

        Test.startTest();
        InstallationsRenewalService.processRenewalInstallations(new List<Installation__c>{ instRecord });
        Test.stopTest();

        Integer lineCount = [
            SELECT COUNT()
            FROM Installation_Line__c
            WHERE Installation__c = :inst.Id
        ];
        System.assertEquals(0, lineCount, 'No installation lines should be created when there are no subscriptions');

        Map<Id, List<SBQQ__Subscription__c>> subsMap =
            InstallationsRenewalService.fetchSubscriptionsByInstallations(new List<Installation__c>{ instRecord });
        System.assertEquals(0, subsMap.size(), 'Expected no subscriptions to be mapped');
    }
}