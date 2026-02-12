@IsTest
private class InstallationChangeServiceTest {
    private static TestDataFactory_OTG.OrderContext buildCtx() {
        return TestDataFactory_OTG.buildOrderContext('Americas', 'Amendment', 'Draft', true, false);
    }

    @IsTest
    static void testPendingImplementationChange() {
        TestDataFactory_OTG.OrderContext ctx = buildCtx();

        Test.startTest();
        update new Installation__c(
            Id = ctx.installation.Id,
            Installation_Order_Status__c = 'Active',
            Order__c = ctx.orderRec.Id
        );
        Test.stopTest();

        List<Installation_Change__c> changes = [
            SELECT Id, Change_Type__c, Order__c
            FROM Installation_Change__c
            WHERE Installation__c = :ctx.installation.Id
        ];
        System.assertEquals(true, containsType(changes, 'Activated'), 'Expected Activated change');
        Installation_Change__c activated = firstByType(changes, 'Activated');
        System.assertEquals(ctx.orderRec.Id, activated.Order__c, 'Expected order populated');
    }

    @IsTest
    static void testPackageChangeInProgress() {
        TestDataFactory_OTG.OrderContext ctx = buildCtx();
        Package__c newPkg = TestDataFactory_OTG.createPackageForContract(
            ctx.packageRec.Contract__c,
            'New Package',
            'USD',
            1,
            1,
            0,
            0,
            0
        );

        Test.startTest();
        update new Installation__c(
            Id = ctx.installation.Id,
            Package__c = newPkg.Id,
            Change_Package_Status__c = 'In Progress'
        );
        Test.stopTest();

        List<Installation_Change__c> changes = [
            SELECT Id, Change_Type__c, Old_Package__c, New_Package__c
            FROM Installation_Change__c
            WHERE Installation__c = :ctx.installation.Id
        ];
        System.assertEquals(true, containsType(changes, 'Package Change'), 'Expected Package Change');
        Installation_Change__c pkgChange = firstByType(changes, 'Package Change');
        System.assertEquals(ctx.packageRec.Id, pkgChange.Old_Package__c, 'Expected old package populated');
        System.assertEquals(newPkg.Id, pkgChange.New_Package__c, 'Expected new package populated');
    }

    @IsTest
    static void testPackageChangeOrderBackfillOnCompletion() {
        TestDataFactory_OTG.OrderContext ctx = buildCtx();
        Package__c newPkg = TestDataFactory_OTG.createPackageForContract(
            ctx.packageRec.Contract__c,
            'New Package',
            'USD',
            1,
            1,
            0,
            0,
            0
        );

        Test.startTest();
        update new Installation__c(
            Id = ctx.installation.Id,
            Package__c = newPkg.Id,
            Change_Package_Status__c = 'In Progress'
        );
        update new Installation__c(
            Id = ctx.installation.Id,
            Change_Package_Status__c = 'Completed',
            Order__c = ctx.orderRec.Id
        );
        Test.stopTest();

        List<Installation_Change__c> changes = [
            SELECT Id, Change_Type__c, Order__c
            FROM Installation_Change__c
            WHERE Installation__c = :ctx.installation.Id
              AND Change_Type__c = 'Package Change'
        ];
        System.assertEquals(1, changes.size(), 'Expected single Package Change record');
        System.assertEquals(ctx.orderRec.Id, changes[0].Order__c, 'Expected order backfilled on completion');
    }



    @IsTest
    static void testRenewalContractChange() {
        TestDataFactory_OTG.OrderContext ctx = buildCtx();
        update new SBQQ__Quote__c(
            Id = ctx.qctx.quote.Id,
            SBQQ__Type__c = 'Renewal'
        );
        Contract newCtr = TestDataFactory_OTG.createContractBasic(
            ctx.qctx.b2bAccount.Id,
            'USD',
            Date.today(),
            12,
            null
        );

        Id oldCtrId = ctx.packageRec.Contract__c;
        if (oldCtrId != null) {
            update new Installation__c(
                Id = ctx.installation.Id,
                Contract__c = oldCtrId
            );
        }

        Test.startTest();
        update new Installation__c(
            Id = ctx.installation.Id,
            Contract__c = newCtr.Id
        );
        Test.stopTest();

        List<Installation_Change__c> changes = [
            SELECT Id, Change_Type__c, Old_Contract__c, New_Contract__c
            FROM Installation_Change__c
            WHERE Installation__c = :ctx.installation.Id
              AND Change_Type__c = 'Renewal'
              AND New_Contract__c = :newCtr.Id
            LIMIT 1
        ];
        System.assertEquals(1, changes.size(), 'Expected Renewal change');
        Installation_Change__c renewal = changes[0];
        System.assertEquals(oldCtrId, renewal.Old_Contract__c, 'Expected old contract populated');
        System.assertEquals(newCtr.Id, renewal.New_Contract__c, 'Expected new contract populated');
    }

    private static Boolean containsType(List<Installation_Change__c> changes, String changeType) {
        for (Installation_Change__c c : changes) {
            if (c.Change_Type__c == changeType) {
                return true;
            }
        }
        return false;
    }

    private static Installation_Change__c firstByType(List<Installation_Change__c> changes, String changeType) {
        for (Installation_Change__c c : changes) {
            if (c.Change_Type__c == changeType) {
                return c;
            }
        }
        return null;
    }
}
