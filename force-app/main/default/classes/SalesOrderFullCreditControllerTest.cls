@IsTest
private class SalesOrderFullCreditControllerTest {
    @TestSetup
    static void setupOrgDefaults() {
        TestDataFactory_OTG.enableOrgVRConfig();
        TestDataFactory_OTG.primeDefaultOwnerAllRegions(UserInfo.getUserId());

        VRConfiguration__c config = VRConfiguration__c.getOrgDefaults();
        if (config == null) {
            config = new VRConfiguration__c();
        }
        upsert config;
    }

    @IsTest
    static void testProcessFullCreditCreatesCreditOrderAndNegativeItems() {
        TestDataFactory_OTG.OrderContext ctx =
            TestDataFactory_OTG.buildOrderContext('Americas', 'Amendment', 'Draft', true, false);

        Contract contractRec = [
            SELECT Id, CurrencyIsoCode
            FROM Contract
            WHERE Id = :ctx.packageRec.Contract__c
        ];

        Account invoiceAccount = new Account(Name = 'Full Credit Invoice Account');
        insert invoiceAccount;

        Sales_Order__c sourceOrder = new Sales_Order__c(
            Contract__c = contractRec.Id,
            Installation__c = ctx.installation.Id,
            Invoice_Account__c = invoiceAccount.Id,
            Start_Date__c = Date.today().addDays(-15),
            End_Date__c = Date.today().addDays(15),
            Status__c = 'Billed',
            Credit_Note__c = false,
            CurrencyIsoCode = contractRec.CurrencyIsoCode
        );
        insert sourceOrder;

        Installation_Line__c installationLine = new Installation_Line__c(
            Name = 'Credit Line',
            Installation__c = ctx.installation.Id,
            Start_Date__c = Date.today().addDays(-15),
            End_Date__c = Date.today().addDays(15),
            Net_Total__c = 150.50,
            CurrencyIsoCode = contractRec.CurrencyIsoCode
        );
        insert installationLine;

        List<Sales_Order_Item__c> sourceItems = new List<Sales_Order_Item__c>{
            new Sales_Order_Item__c(
                Name = 'Positive Item',
                Sales_Order__c = sourceOrder.Id,
                Installation_Line__c = installationLine.Id,
                CurrencyIsoCode = contractRec.CurrencyIsoCode,
                Amount__c = 125.50
            ),
            new Sales_Order_Item__c(
                Name = 'Already Negative Item',
                Sales_Order__c = sourceOrder.Id,
                Installation_Line__c = installationLine.Id,
                CurrencyIsoCode = contractRec.CurrencyIsoCode,
                Amount__c = -25
            )
        };
        insert sourceItems;

        Test.startTest();
        Id creditOrderId = SalesOrderFullCreditController.processFullCredit(sourceOrder.Id);
        Test.stopTest();

        System.assertNotEquals(null, creditOrderId, 'A new credit sales order should be created.');
        System.assertNotEquals(sourceOrder.Id, creditOrderId, 'Full credit should create a new sales order.');

        Sales_Order__c creditOrder = [
            SELECT Contract__c, Installation__c, Invoice_Account__c, Start_Date__c,
                   End_Date__c, Status__c, Credit_Note__c, Original_Sales_Order__c, CurrencyIsoCode
            FROM Sales_Order__c
            WHERE Id = :creditOrderId
        ];
        System.assertEquals(sourceOrder.Contract__c, creditOrder.Contract__c, 'Contract should be copied.');
        System.assertEquals(sourceOrder.Installation__c, creditOrder.Installation__c, 'Installation should be copied.');
        System.assertEquals(sourceOrder.Invoice_Account__c, creditOrder.Invoice_Account__c, 'Invoice account should be copied.');
        System.assertEquals(sourceOrder.Start_Date__c, creditOrder.Start_Date__c, 'Start date should be copied.');
        System.assertEquals(sourceOrder.End_Date__c, creditOrder.End_Date__c, 'End date should be copied.');
        System.assertEquals('Pending Approval', creditOrder.Status__c, 'Credit order should be pending approval.');
        System.assertEquals(true, creditOrder.Credit_Note__c, 'Credit note should be flagged.');
        System.assertEquals(sourceOrder.Id, creditOrder.Original_Sales_Order__c,
            'Credit order should link back to the original sales order.');

        List<Sales_Order_Item__c> creditItems = [
            SELECT Name, Amount__c, Sales_Order__c
            FROM Sales_Order_Item__c
            WHERE Sales_Order__c = :creditOrderId
            ORDER BY Name
        ];
        System.assertEquals(2, creditItems.size(), 'All source items should be cloned.');
        System.assertEquals(-25, creditItems[0].Amount__c, 'Negative amounts should remain negative.');
        System.assertEquals(-125.50, creditItems[1].Amount__c, 'Positive amounts should be flipped to negative.');
    }

    @IsTest
    static void testProcessFullCreditRejectsExistingCreditNote() {
        TestDataFactory_OTG.OrderContext ctx =
            TestDataFactory_OTG.buildOrderContext('Americas', 'Amendment', 'Draft', true, false);

        Contract contractRec = [
            SELECT Id, CurrencyIsoCode
            FROM Contract
            WHERE Id = :ctx.packageRec.Contract__c
        ];

        Sales_Order__c creditOrder = new Sales_Order__c(
            Contract__c = contractRec.Id,
            Installation__c = ctx.installation.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addMonths(1),
            Status__c = 'Unbilled',
            Credit_Note__c = true,
            CurrencyIsoCode = contractRec.CurrencyIsoCode
        );
        insert creditOrder;

        Installation_Line__c installationLine = new Installation_Line__c(
            Name = 'Existing Credit Line',
            Installation__c = ctx.installation.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addMonths(1),
            Net_Total__c = 10,
            CurrencyIsoCode = contractRec.CurrencyIsoCode
        );
        insert installationLine;

        insert new Sales_Order_Item__c(
            Name = 'Credit Item',
            Sales_Order__c = creditOrder.Id,
            Installation_Line__c = installationLine.Id,
            CurrencyIsoCode = contractRec.CurrencyIsoCode,
            Amount__c = -10
        );

        try {
            SalesOrderFullCreditController.processFullCredit(creditOrder.Id);
            System.assert(false, 'Expected existing credit notes to be rejected.');
        } catch (AuraHandledException ex) {
            String message = ex.getMessage();
            System.assert(
                message.contains('already a credit note') || message.contains('Script-thrown exception'),
                'Expected the existing credit note validation to be raised.'
            );
        }
    }
}
