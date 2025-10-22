@IsTest
private class InstallationProductUpdateBatchTest {

    private static TestDataFactory_OTG.OrderContext prepareAmendmentContext() {
        TestDataFactory_OTG.OrderContext ctx =
            TestDataFactory_OTG.buildOrderContext('Americas', 'Amendment', 'Draft', false, false);

        Contract contractRec = [
            SELECT Id, CurrencyIsoCode
            FROM Contract
            WHERE Id = :ctx.packageRec.Contract__c
        ];
        update new Contract(
            Id = contractRec.Id,
            Status = 'Activated'
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
            Type = 'AMENDMENT',
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
    static void testBatchProcessesAmendmentOrder() {
        TestDataFactory_OTG.OrderContext ctx = prepareAmendmentContext();

        Test.startTest();
        Database.executeBatch(new InstallationProductUpdateBatch(new Set<Id>{ ctx.orderRec.Id }), 1);
        Test.stopTest();

        List<Installation_Line__c> lines = [
            SELECT Id
            FROM Installation_Line__c
            WHERE Installation__c = :ctx.installation.Id
        ];
        System.assert(!lines.isEmpty(), 'Batch should create installation lines for amendment order');
    }

    @IsTest
    static void testBatchWithNoMatchingOrders() {
        Test.startTest();
        Database.executeBatch(new InstallationProductUpdateBatch(new Set<Id>()), 1);
        Test.stopTest();
        // Nothing to assert; verifying no exception thrown when no orders provided
    }
}