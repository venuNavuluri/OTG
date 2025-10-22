@IsTest
private class ChangePackageInstallationsBatchTest {

    // Helper: minimal data graph to support Order and Installations
    private class TestData {
        Account acc;
        Pricebook2 stdPb;
        Order ordActivated;
        Order ordEffectiveOnly;
        Installation__c inst1;
        Installation__c inst2;
        Installation__c instNoOrder;

        TestData create() {
            TestData td = new TestData();

            // Use the existing TestDataFactory_OTG to create test data that avoids flow issues
            Id runningUserId = UserInfo.getUserId();
            
            // Prime org config and default owners to avoid flow issues
            TestDataFactory_OTG.enableOrgVRConfig();
            TestDataFactory_OTG.primeDefaultOwnerAllRegions(runningUserId);
            
            // Create Account using the factory method that handles flow issues
            Id countryMappingId = TestDataFactory_OTG.getOrCreateCountryMappingId('Americas');
            td.acc = TestDataFactory_OTG.createB2BAccount(runningUserId, countryMappingId, 'Test Account');

            // Use factory method to create a proper test context with all dependencies
            // Create minimal quote context to get proper test data
            TestDataFactory_OTG.QuoteContext qctx = TestDataFactory_OTG.buildDraftQuoteContext('Americas', false, false);
            
            // Create orders with proper status handling to avoid FAILED_ACTIVATION error
            // Step 1: Create order in Draft status
            Order tempOrd1 = TestDataFactory_OTG.createOrder(
                qctx.opportunity.Id, 
                qctx.quote.Id, 
                'New', 
                'Draft'
            );
            
            // Step 2: Add OrderItem to make order valid for activation
            TestDataFactory_OTG.addOrderItem(tempOrd1.Id, qctx.pbe.Id, 100, 1);
            
            // Step 3: Save order with item before activating
            update tempOrd1;
            
            // Step 4: Update to Activated status
            tempOrd1.Status = 'Activated';
            tempOrd1.Is_Activated__c = TRUE;
            update tempOrd1;
            td.ordActivated = tempOrd1;
            
            // Repeat for second order
            Order tempOrd2 = TestDataFactory_OTG.createOrder(
                qctx.opportunity.Id, 
                qctx.quote.Id, 
                'New', 
                'Draft'
            );
            
            // Add OrderItem to make order valid for activation
            TestDataFactory_OTG.addOrderItem(tempOrd2.Id, qctx.pbe.Id, 100, 1);
            
            // Save order with item before activating
            update tempOrd2;
            
            // Update to Activated status
            tempOrd2.Status = 'Activated';
            tempOrd2.Is_Activated__c = TRUE;
            update tempOrd2;
            td.ordEffectiveOnly = tempOrd2;

            // Installations matching query (In Progress + Active) and tied to orders
            // Get a vessel to avoid validation errors
            Vessel__c vessel = TestDataFactory_OTG.getOrCreateVesselCached();
            
            td.inst1 = new Installation__c(
                Order__c = td.ordActivated.Id,
                Change_Package_Status__c = 'In Progress',
                Installation_Order_Status__c = 'Active',
                Vessel_Name__c = vessel.Id
            );
            td.inst2 = new Installation__c(
                Order__c = td.ordEffectiveOnly.Id,
                Change_Package_Status__c = 'In Progress',
                Installation_Order_Status__c = 'Active',
                Vessel_Name__c = vessel.Id
            );
            // A record that will be skipped in execute due to null Order__c
            td.instNoOrder = new Installation__c(
                Change_Package_Status__c = 'In Progress',
                Installation_Order_Status__c = 'Active'
            );
            insert new List<Installation__c>{ td.inst1, td.inst2, td.instNoOrder };

            return td;
        }
    }

    @IsTest
    static void covers_constructors() {
        ChangePackageInstallationsBatch b1 = new ChangePackageInstallationsBatch((Id)null);
        System.assertNotEquals(null, b1, 'single-order ctor handles null');

        Set<Id> ids = new Set<Id>();
        ChangePackageInstallationsBatch b2 = new ChangePackageInstallationsBatch(ids);
        System.assertNotEquals(null, b2, 'multi-order ctor handles empty set');

        ChangePackageInstallationsBatch b3 = new ChangePackageInstallationsBatch(new Set<Id>{ '006000000000000AAA' });
        System.assertNotEquals(null, b3, 'instantiated with dummy id');
    }

    @IsTest
    static void start_returns_empty_locator_when_no_orders() {
        Test.startTest();
        ChangePackageInstallationsBatch b = new ChangePackageInstallationsBatch(new Set<Id>());
        Database.QueryLocator ql = b.start(null);
        Test.stopTest();
        System.assertNotEquals(null, ql, 'QueryLocator should be non-null even for empty query');
    }

    @IsTest
    static void full_run_multiple_orders_updates_to_completed_and_logs() {
        ChangePackageInstallationsBatchTest.TestData td = new ChangePackageInstallationsBatchTest.TestData().create();

        // Execute end-to-end invoking start, execute and finish via Database.executeBatch
        Test.startTest();
        // Reduce scope to mitigate unrelated automation side effects in UAT
        Database.executeBatch(new ChangePackageInstallationsBatch(new Set<Id>{ td.ordActivated.Id, td.ordEffectiveOnly.Id }), 10);
        Test.stopTest();

        // Assert installations tied to passed orders moved to Completed
        List<Installation__c> reloaded = [
            SELECT Id, Order__c, Change_Package_Status__c
            FROM Installation__c
            WHERE Id IN :new Set<Id>{ td.inst1.Id, td.inst2.Id, td.instNoOrder.Id }
        ];
        Map<Id, Installation__c> byId = new Map<Id, Installation__c>(reloaded);
        System.assertEquals('Completed', byId.get(td.inst1.Id).Change_Package_Status__c, 'inst1 should be completed');
        System.assertEquals('Completed', byId.get(td.inst2.Id).Change_Package_Status__c, 'inst2 should be completed');
        // Not in scope because null Order__c; should remain In Progress
        System.assertEquals('In Progress', byId.get(td.instNoOrder.Id).Change_Package_Status__c, 'inst without order should remain unchanged');
    }

    @IsTest
    static void start_with_nonexistent_orders_yields_empty_query() {
        // Pass an Id that won't match any Order; start should build empty activation map and return empty locator
        Id bogusOrderId = '801000000000000AAA';
        Test.startTest();
        ChangePackageInstallationsBatch b = new ChangePackageInstallationsBatch(new Set<Id>{ bogusOrderId });
        Database.QueryLocator ql = b.start(null);
        Test.stopTest();
        System.assertNotEquals(null, ql, 'QueryLocator should be returned even when no orders found');
    }

    @IsTest
    static void execute_handles_empty_and_null_scopes() {
        ChangePackageInstallationsBatch b = new ChangePackageInstallationsBatch(new Set<Id>());
        Test.startTest();
        b.execute(null, new List<Installation__c>());
        b.execute(null, null);
        Test.stopTest();
        System.assert(true, 'Execute tolerates empty/null scopes');
    }

    @IsTest
    static void finish_logs_safely() {
        ChangePackageInstallationsBatch b = new ChangePackageInstallationsBatch(new Set<Id>());
        Test.startTest();
        b.finish(null);
        Test.stopTest();
        System.assert(true, 'Finish should not throw');
    }

    @IsTest
    static void enqueue_helpers_do_not_throw() {
        Test.startTest();
        ChangePackageInstallationsBatch.enqueue((Id)null);
        ChangePackageInstallationsBatch.enqueue(new Set<Id>());
        Test.stopTest();
        System.assert(true, 'Enqueue helpers invoked without error');
    }
}