@IsTest
private class SalesOrderCloneControllerTest {
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
    static void testCloneSalesOrderCreatesCloneAndChildItems() {
        TestDataFactory_OTG.OrderContext ctx =
            TestDataFactory_OTG.buildOrderContext('Americas', 'Amendment', 'Draft', true, false);

        Contract contractRec = [
            SELECT Id, CurrencyIsoCode
            FROM Contract
            WHERE Id = :ctx.packageRec.Contract__c
        ];

        Account invoiceAccount = new Account(Name = 'Clone Invoice Account');
        insert invoiceAccount;

        Sales_Order__c sourceOrder = new Sales_Order__c(
            Contract__c = contractRec.Id,
            Installation__c = ctx.installation.Id,
            Invoice_Account__c = invoiceAccount.Id,
            Start_Date__c = Date.today().addDays(-10),
            End_Date__c = Date.today().addDays(20),
            Comments__c = 'Original comments',
            Status__c = 'Billed',
            Credit_Note__c = true,
            CurrencyIsoCode = contractRec.CurrencyIsoCode
        );
        insert sourceOrder;

        Installation_Line__c installationLine = new Installation_Line__c(
            Name = 'Clone Line',
            Installation__c = ctx.installation.Id,
            Start_Date__c = Date.today().addDays(-10),
            End_Date__c = Date.today().addDays(20),
            Net_Total__c = 100,
            CurrencyIsoCode = contractRec.CurrencyIsoCode
        );
        insert installationLine;

        insert new List<Sales_Order_Item__c>{
            new Sales_Order_Item__c(
                Name = 'Clone Item 1',
                Sales_Order__c = sourceOrder.Id,
                Installation_Line__c = installationLine.Id,
                CurrencyIsoCode = contractRec.CurrencyIsoCode,
                Amount__c = 75
            ),
            new Sales_Order_Item__c(
                Name = 'Clone Item 2',
                Sales_Order__c = sourceOrder.Id,
                Installation_Line__c = installationLine.Id,
                CurrencyIsoCode = contractRec.CurrencyIsoCode,
                Amount__c = 25
            )
        };

        Test.startTest();
        Id cloneOrderId = SalesOrderCloneController.cloneSalesOrder(sourceOrder.Id);
        Test.stopTest();

        System.assertNotEquals(null, cloneOrderId, 'A cloned sales order should be created.');
        System.assertNotEquals(sourceOrder.Id, cloneOrderId, 'The clone must be a new record.');

        Sales_Order__c clonedOrder = [
            SELECT Contract__c, Installation__c, Invoice_Account__c, Start_Date__c, End_Date__c,
                   Comments__c, Status__c, Credit_Note__c, Original_Sales_Order__c, CurrencyIsoCode
            FROM Sales_Order__c
            WHERE Id = :cloneOrderId
        ];
        System.assertEquals(sourceOrder.Contract__c, clonedOrder.Contract__c, 'Contract should be copied.');
        System.assertEquals(sourceOrder.Installation__c, clonedOrder.Installation__c, 'Installation should be copied.');
        System.assertEquals(sourceOrder.Invoice_Account__c, clonedOrder.Invoice_Account__c, 'Invoice account should be copied.');
        System.assertEquals(sourceOrder.Start_Date__c, clonedOrder.Start_Date__c, 'Start date should be copied.');
        System.assertEquals(sourceOrder.End_Date__c, clonedOrder.End_Date__c, 'End date should be copied.');
        System.assertEquals(sourceOrder.Comments__c, clonedOrder.Comments__c, 'Comments should be copied.');
        System.assertEquals('Pending Approval', clonedOrder.Status__c, 'Cloned order should be pending approval.');
        System.assertEquals(false, clonedOrder.Credit_Note__c, 'Cloned order should not be a credit note.');
        System.assertEquals(sourceOrder.Id, clonedOrder.Original_Sales_Order__c, 'Clone should link to the source order.');

        List<Sales_Order_Item__c> clonedItems = [
            SELECT Name, Amount__c, Sales_Order__c, Installation_Line__c
            FROM Sales_Order_Item__c
            WHERE Sales_Order__c = :cloneOrderId
            ORDER BY Name
        ];
        System.assertEquals(2, clonedItems.size(), 'All source items should be cloned.');
        System.assertEquals('Clone Item 1', clonedItems[0].Name, 'First item should be copied.');
        System.assertEquals(75, clonedItems[0].Amount__c, 'First amount should be copied.');
        System.assertEquals('Clone Item 2', clonedItems[1].Name, 'Second item should be copied.');
        System.assertEquals(25, clonedItems[1].Amount__c, 'Second amount should be copied.');
    }

    @IsTest
    static void testCloneSalesOrderRequiresId() {
        try {
            SalesOrderCloneController.cloneSalesOrder(null);
            System.assert(false, 'Expected a validation error when no sales order id is provided.');
        } catch (AuraHandledException ex) {
            String message = ex.getMessage();
            System.assert(
                message.contains('Sales Order Id is required') || message.contains('Script-thrown exception'),
                'Expected the missing id validation to be raised.'
            );
        }
    }
}
