@IsTest
private class ServiceOrderImplementationControllerTest {
    @TestSetup
    static void setupData() {
        TestDataFactory_OTG.enableOrgVRConfig();
        TestDataFactory_OTG.primeDefaultOwnerAllRegions(UserInfo.getUserId());

        TestDataFactory_OTG.OrderContext ctx =
            TestDataFactory_OTG.buildOrderContext('Americas', 'Amendment', 'Draft', false, false);

        Contract contractRec = [
            SELECT Id, CurrencyIsoCode
            FROM Contract
            WHERE Id = :ctx.packageRec.Contract__c
            LIMIT 1
        ];
        Account invoiceAccount = TestDataFactory_OTG.createInvoiceAccount(
            UserInfo.getUserId(),
            TestDataFactory_OTG.getOrCreateCountryMappingId('Americas'),
            ctx.qctx.b2bAccount.Id
        );
        update new Contract(
            Id = contractRec.Id,
            Status = 'Activated',
            StartDate = Date.today().addMonths(-1),
            EndDate = Date.today().addMonths(11),
            Billing_Frequency__c = 'Monthly'
        );
        update new SBQQ__Quote__c(
            Id = ctx.qctx.quote.Id,
            SBQQ__MasterContract__c = contractRec.Id,
            Requires_Service_Order__c = true
        );
        update new Product2(
            Id = ctx.qctx.product.Id,
            Addendum_Requires_SOW__c = 'Yes'
        );
        update new Order(
            Id = ctx.orderRec.Id,
            Status = 'Activated',
            Is_Activated__c = true
        );
        update new Package__c(
            Id = ctx.packageRec.Id,
            Product_Change_Type__c = 'New Product Added'
        );
        update new Installation__c(
            Id = ctx.installation.Id,
            Contract__c = contractRec.Id,
            Order__c = ctx.orderRec.Id,
            Installation_Order_Status__c = 'Active',
            Installation_Start_Date__c = Date.today(),
            Installation_End_Date__c = Date.today().addMonths(6)
        );

        Order serviceOrder = new Order(
            OpportunityId = ctx.qctx.opportunity.Id,
            Type = 'Service Delivery',
            Status = 'Draft',
            EffectiveDate = Date.today(),
            Pricebook2Id = TestDataFactory_OTG.getStandardPricebookIdCached(),
            Subscription_Order__c = ctx.orderRec.Id
        );
        insert serviceOrder;
        TestDataFactory_OTG.addOrderItem(serviceOrder.Id, ctx.qctx.pbe.Id, 100, 1);

        Installation_Line__c pendingLine = new Installation_Line__c(
            Name = 'Implementation Product',
            Installation__c = ctx.installation.Id,
            Product__c = ctx.qctx.product.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addMonths(6),
            Net_Total__c = 120,
            CurrencyIsoCode = contractRec.CurrencyIsoCode,
            Implementation_Status__c = 'Pending Implementation',
            Change_Action__c = 'Add Product',
            Source_Subscription_Order__c = ctx.orderRec.Id
        );
        insert pendingLine;

        Product2 noSowProduct = new Product2(
            Name = 'No SOW Product',
            IsActive = true,
            Addendum_Requires_SOW__c = 'No'
        );
        insert noSowProduct;

        insert new Installation_Line__c(
            Name = 'No SOW Implementation Product',
            Installation__c = ctx.installation.Id,
            Product__c = noSowProduct.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addMonths(6),
            Net_Total__c = 80,
            CurrencyIsoCode = contractRec.CurrencyIsoCode,
            Implementation_Status__c = 'Pending Implementation',
            Change_Action__c = 'Add Product',
            Source_Subscription_Order__c = ctx.orderRec.Id
        );

        insert new Sales_Order__c(
            Contract__c = contractRec.Id,
            Installation__c = ctx.installation.Id,
            Invoice_Account__c = invoiceAccount.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addMonths(1).addDays(-1),
            Status__c = 'Pending Approval',
            CurrencyIsoCode = contractRec.CurrencyIsoCode
        );
    }

    @IsTest
    static void testGetAndCompleteSelectedLines() {
        Order serviceOrder = [
            SELECT Id
            FROM Order
            WHERE Type = 'Service Delivery'
            LIMIT 1
        ];

        ServiceOrderImplementationController.WorkResponse initialResponse =
            ServiceOrderImplementationController.getImplementationWork(serviceOrder.Id);
        System.assertEquals(1, initialResponse.packages.size(), 'One package should be returned.');
        System.assertEquals(1, initialResponse.installations.size(), 'One installation should be returned.');
        System.assertEquals(1, initialResponse.installations[0].lines.size(), 'Only SOW-required products should be returned.');

        Id lineId = initialResponse.installations[0].lines[0].lineId;

        Test.startTest();
        ServiceOrderImplementationController.WorkResponse completedResponse =
            ServiceOrderImplementationController.completeLines(serviceOrder.Id, new List<Id>{ lineId });
        Test.stopTest();

        System.assertEquals('Completed', completedResponse.installations[0].lines[0].status);
        Installation_Line__c completedLine = [
            SELECT Implementation_Status__c, Implementation_Completed_Date__c, Source_Service_Order__c
            FROM Installation_Line__c
            WHERE Id = :lineId
        ];
        System.assertEquals('Completed', completedLine.Implementation_Status__c);
        System.assertEquals(Date.today(), completedLine.Implementation_Completed_Date__c);
        System.assertEquals(serviceOrder.Id, completedLine.Source_Service_Order__c);
        System.assertEquals(1, [SELECT COUNT() FROM Sales_Order_Item__c WHERE Installation_Line__c = :lineId]);
    }

    @IsTest
    static void testCompletePackageAndServiceOrder() {
        Order serviceOrder = [
            SELECT Id
            FROM Order
            WHERE Type = 'Service Delivery'
            LIMIT 1
        ];
        Package__c pkg = [
            SELECT Id
            FROM Package__c
            WHERE Product_Change_Type__c = 'New Product Added'
            LIMIT 1
        ];

        Test.startTest();
        ServiceOrderImplementationController.completePackage(serviceOrder.Id, pkg.Id);
        ServiceOrderImplementationController.WorkResponse response =
            ServiceOrderImplementationController.completeServiceOrder(serviceOrder.Id);
        Test.stopTest();

        System.assertEquals(true, response.orderSummary.serviceImplementationCompleted);
        Order refreshedServiceOrder = [
            SELECT Service_Implementation_Completed__c
            FROM Order
            WHERE Id = :serviceOrder.Id
        ];
        System.assertEquals(true, refreshedServiceOrder.Service_Implementation_Completed__c);
    }

    @IsTest
    static void testCompleteInstallationUsesSelectedCompletionDate() {
        Order serviceOrder = [
            SELECT Id
            FROM Order
            WHERE Type = 'Service Delivery'
            LIMIT 1
        ];
        Installation_Line__c pendingLine = [
            SELECT Id, Installation__c
            FROM Installation_Line__c
            WHERE Implementation_Status__c = 'Pending Implementation'
            LIMIT 1
        ];
        Date selectedCompletionDate = Date.today().addDays(-7);

        Test.startTest();
        ServiceOrderImplementationController.completeInstallationWithDate(
            serviceOrder.Id,
            pendingLine.Installation__c,
            selectedCompletionDate
        );
        Test.stopTest();

        Installation_Line__c completedLine = [
            SELECT Implementation_Status__c, Implementation_Completed_Date__c, Source_Service_Order__c
            FROM Installation_Line__c
            WHERE Id = :pendingLine.Id
        ];
        System.assertEquals('Completed', completedLine.Implementation_Status__c);
        System.assertEquals(selectedCompletionDate, completedLine.Implementation_Completed_Date__c);
        System.assertEquals(serviceOrder.Id, completedLine.Source_Service_Order__c);
    }

    @IsTest
    static void testCompleteInstallationRejectsDateOutsideContractPeriod() {
        Order serviceOrder = [
            SELECT Id, Subscription_Order__r.SBQQ__Quote__r.SBQQ__MasterContract__r.StartDate
            FROM Order
            WHERE Type = 'Service Delivery'
            LIMIT 1
        ];
        Installation_Line__c pendingLine = [
            SELECT Id, Installation__c
            FROM Installation_Line__c
            WHERE Implementation_Status__c = 'Pending Implementation'
            LIMIT 1
        ];
        Date invalidCompletionDate =
            serviceOrder.Subscription_Order__r.SBQQ__Quote__r.SBQQ__MasterContract__r.StartDate.addDays(-1);

        try {
            ServiceOrderImplementationController.completeInstallationWithDate(
                serviceOrder.Id,
                pendingLine.Installation__c,
                invalidCompletionDate
            );
            System.assert(false, 'Expected validation error when completion date is before the contract start date.');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex, 'Expected AuraHandledException for invalid completion date.');
        }
    }

    @IsTest
    static void testGetImplementationWorkRequiresActivatedSubscriptionOrder() {
        Order serviceOrder = [
            SELECT Id, Subscription_Order__c, Subscription_Order__r.SBQQ__Quote__c
            FROM Order
            WHERE Type = 'Service Delivery'
            LIMIT 1
        ];
        update new SBQQ__Quote__c(
            Id = serviceOrder.Subscription_Order__r.SBQQ__Quote__c,
            SBQQ__Type__c = 'Amendment',
            Requires_Service_Order__c = true
        );
        update new Order(
            Id = serviceOrder.Subscription_Order__c,
            Status = 'Draft',
            Is_Activated__c = false
        );

        try {
            ServiceOrderImplementationController.getImplementationWork(serviceOrder.Id);
            System.assert(false, 'Expected validation error when opening implementation for inactive subscription order.');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex, 'Expected AuraHandledException for inactive subscription order.');
        }
    }

    @IsTest
    static void testCompleteLinesRequiresActivatedSubscriptionOrder() {
        Order serviceOrder = [
            SELECT Id, Subscription_Order__c, Subscription_Order__r.SBQQ__Quote__c
            FROM Order
            WHERE Type = 'Service Delivery'
            LIMIT 1
        ];
        update new SBQQ__Quote__c(
            Id = serviceOrder.Subscription_Order__r.SBQQ__Quote__c,
            SBQQ__Type__c = 'Amendment',
            Requires_Service_Order__c = true
        );
        update new Order(
            Id = serviceOrder.Subscription_Order__c,
            Status = 'Draft',
            Is_Activated__c = false
        );
        Id lineId = [
            SELECT Id
            FROM Installation_Line__c
            WHERE Implementation_Status__c = 'Pending Implementation'
            LIMIT 1
        ].Id;

        try {
            ServiceOrderImplementationController.completeLines(serviceOrder.Id, new List<Id>{ lineId });
            System.assert(false, 'Expected validation error when subscription order is not activated.');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex, 'Expected AuraHandledException for inactive subscription order.');
        }
    }
}
