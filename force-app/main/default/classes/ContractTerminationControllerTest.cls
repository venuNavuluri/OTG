@IsTest
private class ContractTerminationControllerTest {
    private class ContractTerminationContext {
        Id contractId;
        Id installationId;
        String currencyIsoCode;
    }

    @TestSetup
    static void setupOrgDefaults() {
        TestDataFactory_OTG.enableOrgVRConfig();
        TestDataFactory_OTG.primeDefaultOwnerAllRegions(UserInfo.getUserId());
    }

    private static ContractTerminationContext buildContext(Date contractStart, Date contractEnd) {
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
            StartDate = contractStart,
            EndDate = contractEnd,
            Billing_Frequency__c = 'Monthly'
        );

        update new Installation__c(
            Id = ctx.installation.Id,
            Contract__c = contractRec.Id,
            Installation_Order_Status__c = 'Active',
            Installation_Start_Date__c = contractStart,
            Installation_End_Date__c = contractEnd,
            CurrencyIsoCode = contractRec.CurrencyIsoCode
        );

        ContractTerminationContext data = new ContractTerminationContext();
        data.contractId = contractRec.Id;
        data.installationId = ctx.installation.Id;
        data.currencyIsoCode = contractRec.CurrencyIsoCode;
        return data;
    }

    @IsTest
    static void testRequestTerminationRejectsDateOutsideContractPeriod() {
        ContractTerminationContext ctx = buildContext(Date.today().addMonths(-1), Date.today().addMonths(2));

        try {
            ContractTerminationController.requestTermination(
                ctx.contractId,
                Date.today().addMonths(3),
                'Other',
                'Outside contract period'
            );
            System.assert(false, 'Expected requestTermination to reject a date outside the contract period.');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage(), 'Expected a handled validation exception.');
        }
    }

    @IsTest
    static void testRequestTerminationValidatesRequiredInputsAndAlreadyTerminatedContracts() {
        ContractTerminationContext ctx = buildContext(Date.today().addMonths(-1), Date.today().addMonths(2));

        try {
            ContractTerminationController.requestTermination(null, Date.today(), 'Other', 'Missing contract id');
            System.assert(false, 'Expected contract id validation to fire.');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage(), 'Expected handled validation for missing contract id.');
        }

        try {
            ContractTerminationController.requestTermination(ctx.contractId, null, 'Other', 'Missing date');
            System.assert(false, 'Expected termination date validation to fire.');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage(), 'Expected handled validation for missing termination date.');
        }

        try {
            ContractTerminationController.requestTermination(ctx.contractId, Date.today(), '', 'Missing reason');
            System.assert(false, 'Expected lost reason validation to fire.');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage(), 'Expected handled validation for missing lost reason.');
        }

        try {
            ContractTerminationController.requestTermination(ctx.contractId, Date.today(), 'Other', '');
            System.assert(false, 'Expected lost reason comments validation to fire.');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage(), 'Expected handled validation for missing lost reason comments.');
        }

        update new Contract(
            Id = ctx.contractId,
            Status = 'Terminated',
            Terminated_Date__c = Date.today(),
            Lost_Reason__c = 'Other',
            Lost_Reason_Comments__c = 'Already terminated'
        );

        try {
            ContractTerminationController.requestTermination(
                ctx.contractId,
                Date.today(),
                'Other',
                'Second termination attempt'
            );
            System.assert(false, 'Expected already-terminated contract validation to fire.');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage(), 'Expected handled validation for already terminated contract.');
        }
    }

    @IsTest
    static void testRequestTerminationTerminatesInstallationsAndProcessesSalesOrders() {
        Date contractStart = Date.today().addMonths(-2);
        Date contractEnd = Date.today().addMonths(10);
        ContractTerminationContext ctx = buildContext(contractStart, contractEnd);

        Installation_Line__c instLine = new Installation_Line__c(
            Name = 'Contract Termination Line',
            Installation__c = ctx.installationId,
            Start_Date__c = Date.today().addMonths(-1),
            End_Date__c = Date.today().addMonths(1),
            Net_Total__c = 900,
            CurrencyIsoCode = ctx.currencyIsoCode
        );
        insert instLine;

        Sales_Order__c overlappingPending = new Sales_Order__c(
            Installation__c = ctx.installationId,
            Contract__c = ctx.contractId,
            Start_Date__c = Date.today().addDays(-5),
            End_Date__c = Date.today().addDays(25),
            Status__c = 'Pending Approval',
            CurrencyIsoCode = ctx.currencyIsoCode
        );
        Sales_Order__c futurePending = new Sales_Order__c(
            Installation__c = ctx.installationId,
            Contract__c = ctx.contractId,
            Start_Date__c = Date.today().addDays(10),
            End_Date__c = Date.today().addDays(35),
            Status__c = 'Pending Approval',
            CurrencyIsoCode = ctx.currencyIsoCode
        );
        Sales_Order__c billedSalesOrder = new Sales_Order__c(
            Installation__c = ctx.installationId,
            Contract__c = ctx.contractId,
            Start_Date__c = Date.today().addDays(-10),
            End_Date__c = Date.today().addDays(20),
            Status__c = 'Billed',
            CurrencyIsoCode = ctx.currencyIsoCode
        );
        insert new List<Sales_Order__c>{ overlappingPending, futurePending, billedSalesOrder };

        insert new Sales_Order_Item__c(
            Sales_Order__c = billedSalesOrder.Id,
            Installation_Line__c = instLine.Id,
            Amount__c = 900,
            CurrencyIsoCode = ctx.currencyIsoCode,
            Name = 'Credit Source Item'
        );

        Date terminationDate = Date.today();

        Test.startTest();
        ContractTerminationController.requestTermination(
            ctx.contractId,
            terminationDate,
            'Other',
            'Customer requested cancellation'
        );
        Test.stopTest();

        Contract refreshedContract = [
            SELECT Status, Terminated_Date__c, Lost_Reason__c, Lost_Reason_Comments__c
            FROM Contract
            WHERE Id = :ctx.contractId
        ];
        System.assertEquals('Terminated', refreshedContract.Status, 'Contract should be terminated.');
        System.assertEquals(terminationDate, refreshedContract.Terminated_Date__c, 'Terminated date should be stored.');
        System.assertEquals('Other', refreshedContract.Lost_Reason__c, 'Lost reason should be stored.');

        Installation__c refreshedInstallation = [
            SELECT Installation_Order_Status__c, Termination_End_Date__c, Termination_Reason__c, Installation_End_Date__c
            FROM Installation__c
            WHERE Id = :ctx.installationId
        ];
        System.assertEquals('Terminated', refreshedInstallation.Installation_Order_Status__c,
            'Active installation should be terminated by the contract batch.');
        System.assertEquals(terminationDate, refreshedInstallation.Termination_End_Date__c,
            'Installation termination date should match the contract termination date.');
        System.assertEquals(terminationDate, refreshedInstallation.Installation_End_Date__c,
            'Installation end date should be truncated to the contract termination date.');
        System.assert(
            refreshedInstallation.Termination_Reason__c.contains('Lost Reason: Other'),
            'Installation termination reason should inherit contract lost reason details.'
        );

        Map<Id, Sales_Order__c> openOrders = new Map<Id, Sales_Order__c>([
            SELECT Id, Status__c
            FROM Sales_Order__c
            WHERE Id IN :new Set<Id>{ overlappingPending.Id, futurePending.Id }
        ]);
        System.assertEquals('Cancelled', openOrders.get(overlappingPending.Id).Status__c,
            'Overlapping open order should be cancelled.');
        System.assertEquals('Cancelled', openOrders.get(futurePending.Id).Status__c,
            'Future open order should also be cancelled without replacement.');

        List<Sales_Order__c> creditOrders = [
            SELECT Id, Credit_Note__c, Start_Date__c, End_Date__c, Status__c
            FROM Sales_Order__c
            WHERE Installation__c = :ctx.installationId
              AND Credit_Note__c = true
        ];
        System.assertEquals(1, creditOrders.size(), 'Billed sales order should generate one credit note.');
        System.assertEquals('Pending Approval', creditOrders[0].Status__c, 'Credit note should be pending approval.');
        System.assertEquals(terminationDate, creditOrders[0].Start_Date__c,
            'Partial credit note should start on the contract termination date.');

        List<Sales_Order_Item__c> creditItems = [
            SELECT Amount__c
            FROM Sales_Order_Item__c
            WHERE Sales_Order__c = :creditOrders[0].Id
        ];
        System.assertEquals(1, creditItems.size(), 'Credit note should receive a credit item.');
        System.assert(creditItems[0].Amount__c < 0, 'Credit item should be negative.');

        List<Sales_Order__c> replacementOrders = [
            SELECT Id, Credit_Note__c, Start_Date__c, End_Date__c, Status__c, Original_Sales_Order__c
            FROM Sales_Order__c
            WHERE Installation__c = :ctx.installationId
              AND Credit_Note__c = false
              AND Original_Sales_Order__c = :overlappingPending.Id
        ];
        System.assertEquals(1, replacementOrders.size(),
            'Overlapping open sales order should create one replacement order.');
        System.assertEquals('Pending Approval', replacementOrders[0].Status__c,
            'Replacement order should stay in pending approval.');
        System.assertEquals(overlappingPending.Start_Date__c, replacementOrders[0].Start_Date__c,
            'Replacement order should keep the original start date.');
        System.assertEquals(terminationDate, replacementOrders[0].End_Date__c,
            'Replacement order should end on the contract termination date.');

        List<Sales_Order_Item__c> replacementItems = [
            SELECT Amount__c
            FROM Sales_Order_Item__c
            WHERE Sales_Order__c = :replacementOrders[0].Id
        ];
        System.assertEquals(1, replacementItems.size(),
            'Replacement order should receive one prorated item.');
        Decimal expectedReplacementAmount = (
            instLine.Net_Total__c /
            (instLine.Start_Date__c.daysBetween(instLine.End_Date__c) + 1) *
            (overlappingPending.Start_Date__c.daysBetween(terminationDate) + 1)
        ).setScale(2);
        System.assertEquals(expectedReplacementAmount, replacementItems[0].Amount__c,
            'Replacement order should prorate through the termination date.');

        Integer futureReplacementCount = [
            SELECT Count()
            FROM Sales_Order__c
            WHERE Installation__c = :ctx.installationId
              AND Credit_Note__c = false
              AND Original_Sales_Order__c = :futurePending.Id
        ];
        System.assertEquals(0, futureReplacementCount,
            'Future open sales order should not get a replacement order.');
    }

    @IsTest
    static void testRequestTerminationAtContractEndSkipsSalesOrderChanges() {
        Date contractStart = Date.today().addMonths(-2);
        Date contractEnd = Date.today().addDays(15);
        ContractTerminationContext ctx = buildContext(contractStart, contractEnd);

        Sales_Order__c pendingSalesOrder = new Sales_Order__c(
            Installation__c = ctx.installationId,
            Contract__c = ctx.contractId,
            Start_Date__c = Date.today().addDays(-5),
            End_Date__c = Date.today().addDays(25),
            Status__c = 'Pending Approval',
            CurrencyIsoCode = ctx.currencyIsoCode
        );
        insert pendingSalesOrder;

        Test.startTest();
        ContractTerminationController.requestTermination(
            ctx.contractId,
            contractEnd,
            'Other',
            'Contract naturally ends today'
        );
        Test.stopTest();

        Installation__c refreshedInstallation = [
            SELECT Installation_Order_Status__c, Termination_End_Date__c
            FROM Installation__c
            WHERE Id = :ctx.installationId
        ];
        System.assertEquals('Terminated', refreshedInstallation.Installation_Order_Status__c,
            'Installation should still be terminated when the contract is terminated at its end date.');
        System.assertEquals(contractEnd, refreshedInstallation.Termination_End_Date__c,
            'Installation termination date should still be stamped.');

        Sales_Order__c refreshedPendingOrder = [
            SELECT Status__c
            FROM Sales_Order__c
            WHERE Id = :pendingSalesOrder.Id
        ];
        System.assertEquals('Pending Approval', refreshedPendingOrder.Status__c,
            'Sales orders should remain unchanged when the termination date equals the contract end date.');

        Integer creditOrderCount = [
            SELECT Count()
            FROM Sales_Order__c
            WHERE Installation__c = :ctx.installationId
              AND Credit_Note__c = true
        ];
        System.assertEquals(0, creditOrderCount,
            'No credit note should be created when the contract ends on its scheduled end date.');
    }
}
