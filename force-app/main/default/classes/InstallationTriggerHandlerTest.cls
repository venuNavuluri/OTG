@IsTest
private class InstallationTriggerHandlerTest {

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
       // config.ByPass_Opportunity_Triggers__c = true;
       // config.ByPass_Flow__c = true;
        upsert config;
    }

    @IsTest
    static void testBeforeInsertPreventsDuplicateVesselInstallation() {
        TestDataFactory_OTG.OrderContext ctx =
            TestDataFactory_OTG.buildOrderContext('Americas', 'Amendment', 'Draft', true, false);

        Installation__c existing = [
            SELECT Id, Package__c, Vessel_Name__c, Quote__c
            FROM Installation__c
            WHERE Id = :ctx.installation.Id
        ];

        update new Installation__c(
            Id = existing.Id,
            Installation_Order_Status__c = 'Active',
            Installation_Type__c = 'Vessel',
            Vessel_Name__c = existing.Vessel_Name__c
        );

        Installation__c duplicate = new Installation__c(
            Package__c = existing.Package__c,
            Installation_Type__c = 'Vessel',
            Vessel_Name__c = existing.Vessel_Name__c,
            Installation_Order_Status__c = 'Active',
            Quote__c = existing.Quote__c
        );

        try {
            insert duplicate;
            System.assert(false, 'Expected duplicate installation insert to fail.');
        } catch (DmlException ex) {
            System.assert(ex.getMessage().contains('Duplicate installation record'),
                'Duplicate error message should mention duplicate installation record.');
        }
    }

    @IsTest
    static void testHandleTerminatedInstallationsCreatesCreditNote() {
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
            Billing_Frequency__c = 'Monthly'
        );

        Installation__c inst = [
            SELECT Id, Package__c, Quote__c
            FROM Installation__c
            WHERE Id = :ctx.installation.Id
        ];

        update new Installation__c(
            Id = inst.Id,
            Installation_Order_Status__c = 'Active',
            Contract__c = contractRec.Id,
            Installation_Start_Date__c = Date.today().addMonths(-1),
            Installation_End_Date__c = Date.today().addMonths(11),
            CurrencyIsoCode = contractRec.CurrencyIsoCode
        );

        Installation_Line__c instLine = new Installation_Line__c(
            Name = 'Active Line',
            Installation__c = inst.Id,
            Start_Date__c = Date.today().addMonths(-1),
            End_Date__c = Date.today().addMonths(1),
            Net_Total__c = 900,
            CurrencyIsoCode = contractRec.CurrencyIsoCode
        );
        insert instLine;

        Sales_Order__c unbilledSO = new Sales_Order__c(
            Installation__c = inst.Id,
            Contract__c = contractRec.Id,
            Start_Date__c = Date.today().addDays(-5),
            End_Date__c = Date.today().addDays(35),
            Status__c = 'Pending Approval',
            CurrencyIsoCode = contractRec.CurrencyIsoCode
        );

        Sales_Order__c billedSO = new Sales_Order__c(
            Installation__c = inst.Id,
            Contract__c = contractRec.Id,
            Start_Date__c = Date.today().addDays(-15),
            End_Date__c = Date.today().addDays(15),
            Status__c = 'Billed',
            CurrencyIsoCode = contractRec.CurrencyIsoCode
        );
        insert new List<Sales_Order__c>{ unbilledSO, billedSO };

        insert new Sales_Order_Item__c(
            Sales_Order__c = billedSO.Id,
            Installation_Line__c = instLine.Id,
            Amount__c = 900,
            CurrencyIsoCode = contractRec.CurrencyIsoCode,
            Name = 'Primary Item'
        );

        Date terminationDate = Date.today();

        Test.startTest();
        InstallationTriggerHandler.handleTerminatedInstallations(
            new List<Id>{ inst.Id },
            terminationDate
        );
        Test.stopTest();

        Sales_Order__c refreshedUnbilled = [
            SELECT Status__c
            FROM Sales_Order__c
            WHERE Id = :unbilledSO.Id
        ];
        System.assertEquals('Cancelled', refreshedUnbilled.Status__c,
            'Unbilled sales order should be cancelled on termination.');

        List<Sales_Order__c> replacementOrders = [
            SELECT Id, Credit_Note__c, Start_Date__c, End_Date__c, Status__c, Original_Sales_Order__c
            FROM Sales_Order__c
            WHERE Installation__c = :inst.Id
                AND Credit_Note__c = false
                AND Original_Sales_Order__c = :unbilledSO.Id
        ];
        System.assertEquals(1, replacementOrders.size(), 'A truncated replacement order should be created.');
        System.assertEquals('Pending Approval', replacementOrders[0].Status__c,
            'Replacement order should remain in pending approval.');
        System.assertEquals(unbilledSO.Start_Date__c, replacementOrders[0].Start_Date__c,
            'Replacement order should keep the original start date.');
        System.assertEquals(terminationDate, replacementOrders[0].End_Date__c,
            'Replacement order should end on the termination date.');

        List<Sales_Order_Item__c> replacementItems = [
            SELECT Amount__c
            FROM Sales_Order_Item__c
            WHERE Sales_Order__c = :replacementOrders[0].Id
        ];
        System.assertEquals(1, replacementItems.size(), 'Replacement order should receive one prorated item.');
        Decimal expectedReplacementAmount = (
            instLine.Net_Total__c /
            (instLine.Start_Date__c.daysBetween(instLine.End_Date__c) + 1) *
            (unbilledSO.Start_Date__c.daysBetween(terminationDate) + 1)
        ).setScale(2);
        System.assertEquals(expectedReplacementAmount, replacementItems[0].Amount__c,
            'Replacement order item should include the termination date when prorating.');

        List<Sales_Order__c> creditOrders = [
            SELECT Id, Credit_Note__c, Start_Date__c, End_Date__c, Status__c
            FROM Sales_Order__c
            WHERE Installation__c = :inst.Id AND Credit_Note__c = true
        ];
        System.assertEquals(1, creditOrders.size(), 'Exactly one credit note should be created.');
        System.assertEquals('Pending Approval', creditOrders[0].Status__c, 'Credit note should be unbilled.');
        System.assertEquals(terminationDate, creditOrders[0].Start_Date__c,
            'Credit note should start on termination date.');

        List<Sales_Order_Item__c> creditItems = [
            SELECT Amount__c
            FROM Sales_Order_Item__c
            WHERE Sales_Order__c = :creditOrders[0].Id
        ];
        System.assertEquals(1, creditItems.size(), 'Credit note should receive one item.');
        System.assert(creditItems[0].Amount__c < 0, 'Credit note item should refund (negative amount).');
    }

    @IsTest
    static void testAfterUpdateFutureTerminatedOnlyUpdatesStatus() {
        TestDataFactory_OTG.OrderContext ctx =
            TestDataFactory_OTG.buildOrderContext('Americas', 'Amendment', 'Draft', true, false);

        Contract contractRec = [
            SELECT Id
            FROM Contract
            WHERE Id = :ctx.packageRec.Contract__c
        ];

        Date contractStart = Date.today().addDays(-30);
        Date contractEnd = Date.today().addDays(90);
        update new Contract(
            Id = contractRec.Id,
            Status = 'Activated',
            StartDate = contractStart,
            EndDate = contractEnd,
            Billing_Frequency__c = 'Monthly'
        );

        Installation__c inst = [
            SELECT Id, Contract__c, Package__c
            FROM Installation__c
            WHERE Id = :ctx.installation.Id
        ];

        Date terminationDate = Date.today().addDays(10);

        Test.startTest();
        update new Installation__c(
            Id = inst.Id,
            Contract__c = contractRec.Id,
            Package__c = inst.Package__c,
            Installation_Order_Status__c = 'Future Terminated',
            Termination_End_Date__c = terminationDate,
            Termination_Reason__c = 'Scheduled'
        );
        Test.stopTest();

        Installation__c refreshed = [
            SELECT Installation_Order_Status__c, Auto_Installation_Termination_Error__c
            FROM Installation__c
            WHERE Id = :inst.Id
        ];
        System.assertEquals('Future Terminated', refreshed.Installation_Order_Status__c,
            'Future termination should only update the installation status.');
        System.assertEquals(null, refreshed.Auto_Installation_Termination_Error__c,
            'Future termination should not invoke amendment processing from the trigger.');
    }
}