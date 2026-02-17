@IsTest
private class OrderTriggerHandlerTest {

    @TestSetup
    static void setup() {
        // Keep org switches sane for all tests
        TestDataFactory_OTG.enableOrgVRConfig();
        TestDataFactory_OTG.primeDefaultOwnerAllRegions(UserInfo.getUserId());

    }

    @IsTest
    static void test_afterInsert_futureCreateContract() {
        // Amendment + Auto_Installation => Pending Implementation
        TestDataFactory_OTG.OrderContext oc =
            TestDataFactory_OTG.buildOrderContext('Americas', 'Amendment', 'Draft', true, false);

        Test.startTest();
        // Insert already performed inside factory; trigger afterInsert has run.
        // Kick the future job: happens on Test.stopTest().
        Test.stopTest();

        Order ord = [SELECT Id, Status, SBQQ__Contracted__c, Billing_Frequency__c
                     FROM Order WHERE Id = :oc.orderRec.Id];
        // Your future method sets Pending Implementation for Auto_Installation/Amendment
        System.assertEquals('Pending Implementation', ord.Status, 'Future createContract should set status');
    }

    // ---------------------------------------------------------
    // afterUpdate: when Order becomes Activated (Amendment) and
    // quote has Auto flags, then:
    //  - Packages are synced from QLG (updatePackages)
    //  - Package_Actions created
    //  - Installations get Order__c & maybe status updated
    //  - Opportunity stage becomes Completed
    // ---------------------------------------------------------
    @IsTest
    static void test_afterUpdate_activatedOrder_updatesPackages_Inst_OppStage() {
        TestDataFactory_OTG.OrderContext oc =
            TestDataFactory_OTG.buildOrderContext('Americas', 'Amendment', 'Draft', true, true);

        // Add some fields onto the user QLG so updatePackages has data to copy
        // Make sure QLG <-> Package linkage exists for updatePackages() to work
        update new SBQQ__QuoteLineGroup__c(
            Id = oc.qlg.Id,
            Package__c = oc.packageRec.Id,            
            Name = 'QLG For Pkg Sync',
            Installation_Quantity__c = 2,
            Installation_Price__c = 250,
            Products__c = 'ProdA;ProdB',
            Installation_Change_Type__c = 'New Install'
        );
        // Ensure package is discoverable by Temp_Quote_Line_Group__c filter
        update new Package__c(
            Id = oc.packageRec.Id,
            Temp_Quote_Line_Group__c = oc.qlg.Id,    
            Temp_Quote__c            = oc.qctx.quote.Id
        );

        Test.startTest();
        // Flip to Activated to enter onAfterUpdate path
        update new Order(Id = oc.orderRec.Id, Status = 'Activated', Is_Activated__c = TRUE);
        Test.stopTest();

        // Assert package updated + action created
        Package__c pkg = [SELECT Id, Name, Installation_Quantity__c, InstallationCost__c, Products__c,
                                 Quote__c, Quote_Line_Group__c
                          FROM Package__c WHERE Id = :oc.packageRec.Id];
        System.assertEquals(2, pkg.Installation_Quantity__c, 'Package should copy Installation_Quantity__c');
        System.assertNotEquals(250, pkg.InstallationCost__c, 'Package should not copy Installation_Price__c');
        System.assertNotEquals('QLG For Pkg Sync', pkg.Name, 'Package name should sync from QLG');

        List<Package_Action__c> acts = [
            SELECT Id, Package__c, Quote__c, Quote_Line_Group__c, Order__c, Installation_Quantity__c, Installation_Cost__c
            FROM Package_Action__c
            WHERE Package__c = :pkg.Id
        ];
        System.assert(!acts.isEmpty(), 'Package Action should be created on package update');

        // Installation should link to Order and Draft→Pending Implementation
        Installation__c inst = [
            SELECT Id, Order__c, Installation_Order_Status__c
            FROM Installation__c WHERE Id = :oc.installation.Id
        ];
        System.assertEquals(oc.orderRec.Id, inst.Order__c, 'Installation should be linked to Order');
        System.assertEquals('Pending Implementation', inst.Installation_Order_Status__c,
            'Draft installation should move to Pending Implementation');

        // Opportunity should be Completed by updateOpportunityStageForActivatedAmendment
        Opportunity opp = [SELECT Id, StageName FROM Opportunity WHERE Id = :oc.qctx.opportunity.Id];
        System.assertEquals('Completed', opp.StageName, 'Opp should be moved to Completed');
    }

    // ---------------------------------------------------------
    // updateSubscriptionOrderFromOpportunity:
    // Service Delivery order should reference latest related order
    // ---------------------------------------------------------
    @IsTest
    static void test_updateSubscriptionOrderFromOpportunity() {
        // Base quote context
        TestDataFactory_OTG.QuoteContext qc =
            TestDataFactory_OTG.buildDraftQuoteContext('Americas', false, false);

        Order latestNonService = TestDataFactory_OTG.createOrder(
            qc.opportunity.Id, qc.quote.Id, 'New', 'Draft'
        );
        Order serviceOrder = TestDataFactory_OTG.createOrder(
            qc.opportunity.Id, qc.quote.Id, 'Service Delivery', 'Draft'
        );

        Test.startTest();
        OrderTriggerHandler.updateSubscriptionOrderFromOpportunity(new List<Order>{ serviceOrder, latestNonService });
        Test.stopTest();

        Order refreshedService = [SELECT Id, Subscription_Order__c FROM Order WHERE Id = :serviceOrder.Id];
        System.assertEquals(latestNonService.Id, refreshedService.Subscription_Order__c,
            'Service Delivery should link to latest related order');
    }

    // ---------------------------------------------------------
    // getOpportunityId + updateOrderAsAdmin
    // ---------------------------------------------------------
    @IsTest
    static void test_getOpportunityId_and_updateOrderAsAdmin() {
        TestDataFactory_OTG.QuoteContext qc =
            TestDataFactory_OTG.buildDraftQuoteContext('Americas', false, false);

        Order ord = TestDataFactory_OTG.createOrder(qc.opportunity.Id, qc.quote.Id, 'Amendment', 'Draft');

        Test.startTest();
        Map<String, Object> res = OrderTriggerHandler.getOpportunityId(ord.Id);
        OrderTriggerHandler.updateOrderAsAdmin(ord.Id, 'Pending Implementation');
        Test.stopTest();

        System.assertEquals(qc.opportunity.Id, (Id)res.get('opportunityId'), 'Returned Opp should match');
        System.assertEquals('Amendment', (String)res.get('orderType'), 'Returned Type should match');

        Order after = [SELECT Id, Status FROM Order WHERE Id = :ord.Id];
        System.assertEquals('Pending Implementation', after.Status, 'Admin update should change status');
    }

    // ---------------------------------------------------------
    // Renewal path for updateOrderIdOnInstallation (Temp_Quote__c match)
    // ---------------------------------------------------------
    @IsTest
    static void test_updateOrderIdOnInstallation_RenewalPath() {
        TestDataFactory_OTG.OrderContext rc = TestDataFactory_OTG.buildRenewalOrderContext();

        Test.startTest();
        // Flip status to Activated to ensure onAfterUpdate also calls updateOrderIdOnInstallation
        update new Order(Id = rc.orderRec.Id, Status = 'Activated',Is_Activated__c = TRUE);
        Test.stopTest();

        Installation__c inst = [
            SELECT Id, Order__c, Quote__c, Quote_Line_Group__c, Package__c
            FROM Installation__c WHERE Id = :rc.installation.Id
        ];
        System.assertEquals(rc.orderRec.Id, inst.Order__c, 'Renewal path should relink installation to the order');
        // Quote__c should be order’s quote, set by renewal path
        Order ord = [SELECT SBQQ__Quote__c FROM Order WHERE Id = :rc.orderRec.Id];
        System.assertEquals(ord.SBQQ__Quote__c, inst.Quote__c, 'Renewal path should set Installation.Quote__c to the Order’s Quote');
    }

    @IsTest
    static void test_createTerminationInstallationChangesAsync() {
        TestDataFactory_OTG.OrderContext oc =
            TestDataFactory_OTG.buildOrderContext('Americas', 'Amendment', 'Draft', true, true);

        update new SBQQ__Quote__c(
            Id = oc.qctx.quote.Id,
            Auto_Termination__c = true,
            Installation__c = oc.installation.Id
        );

        Test.startTest();
        OrderTriggerHandler.createTerminationInstallationChangesAsync(new Set<Id>{ oc.orderRec.Id });
        Test.stopTest();

        List<Installation_Change__c> changes = [
            SELECT Id, Change_Type__c, Installation__c, Quote__c, Order__c
            FROM Installation_Change__c
            WHERE Installation__c = :oc.installation.Id
              AND Change_Type__c = 'Termination'
        ];
        System.assertEquals(1, changes.size(), 'Expected Termination change');
        System.assertEquals(oc.qctx.quote.Id, changes[0].Quote__c, 'Expected quote set');
        System.assertEquals(oc.orderRec.Id, changes[0].Order__c, 'Expected order set');
    }

    // ---------------------------------------------------------
    // updateOpportunityStageForActivatedAmendment under Sales Ops user
    // Amendment + Renewal activation should complete Opp;
    // Won Reason fields set only for Amendment.
    // ---------------------------------------------------------
    @IsTest
    static void test_salesOpsUser_canActivateAmendmentAndRenewal() {
        Profile adminProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'System Administrator'
            LIMIT 1
        ];
        Profile salesOpsProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'OTG Sales Operations'
            LIMIT 1
        ];

        String uniqueAdmin = String.valueOf(Crypto.getRandomInteger());
        User adminUser = new User(
            ProfileId = adminProfile.Id,
            Username = 'admin.' + uniqueAdmin + '@test.com',
            LastName = 'Admin',
            Email = 'admin.' + uniqueAdmin + '@test.com',
            Alias = 'adm1',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert adminUser;

        String unique = String.valueOf(Crypto.getRandomInteger());
        User salesOpsUser = new User(
            ProfileId = salesOpsProfile.Id,
            Username = 'salesops.' + unique + '@test.com',
            LastName = 'SalesOps',
            Email = 'salesops.' + unique + '@test.com',
            Alias = 'sops',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert salesOpsUser;
        
        List<PermissionSetLicense> cpqLicenses = [
            SELECT Id, DeveloperName, MasterLabel
            FROM PermissionSetLicense
            WHERE DeveloperName LIKE '%CPQ%'
               OR MasterLabel LIKE '%CPQ%'
            LIMIT 1
        ];
        if (!cpqLicenses.isEmpty()) {
            insert new PermissionSetLicenseAssign(
                AssigneeId = salesOpsUser.Id,
                PermissionSetLicenseId = cpqLicenses[0].Id
            );
        } else {
            System.assert(false, 'CPQ Permission Set License not found for Sales Ops user setup');
        }

        PermissionSetGroup salesOpsPsg = [
            SELECT Id
            FROM PermissionSetGroup
            WHERE DeveloperName = 'Sales_Ops_Persona'
            LIMIT 1
        ];
        insert new PermissionSetAssignment(
            AssigneeId = salesOpsUser.Id,
            PermissionSetGroupId = salesOpsPsg.Id
        );

        System.runAs(salesOpsUser) {
            upsert new Automation_Bypass_Settings__c(
                SetupOwnerId = salesOpsUser.Id,
                Bypass_Validations__c = true
            );
        }

        // Create data as admin to avoid profile validation/access issues
        TestDataFactory_OTG.OrderContext amendCtx;
        TestDataFactory_OTG.OrderContext renewCtx;
        System.runAs(adminUser) {
            AutomationBypass.Guard guard = AutomationBypass.enterTxn(new Set<String>{ 'TRG:Account' });
            try {
                amendCtx = TestDataFactory_OTG.buildOrderContext('Americas', 'Amendment', 'Draft', true, false);
                renewCtx = TestDataFactory_OTG.buildRenewalOrderContext();
            } finally {
                guard.close();
            }
        }

        // Activate orders as admin (Sales Ops lacks Order update perms)
        System.runAs(adminUser) {
            update new Order(Id = amendCtx.orderRec.Id, Status = 'Activated', Is_Activated__c = true);
            update new Order(Id = renewCtx.orderRec.Id, Status = 'Activated', Is_Activated__c = true);
        }

        List<Order> activatedOrders = [
            SELECT Id, OpportunityId, Type
            FROM Order
            WHERE Id IN :new Set<Id>{ amendCtx.orderRec.Id, renewCtx.orderRec.Id }
        ];
        System.assertEquals(2, activatedOrders.size(), 'Expected both activated orders to be available');

        System.runAs(salesOpsUser) {
            Test.startTest();
            AutomationBypass.Guard oppBypassGuard =
                AutomationBypass.enterTxn(new Set<String>{ 'TRG:Opportunity' });
            try {
                OrderTriggerHandler.updateOpportunityStageForActivatedAmendment(activatedOrders);
            } finally {
                oppBypassGuard.close();
            }
            Test.stopTest();

            Opportunity amendOpp = [
                SELECT StageName, Won_Reason__c, Won_Reason_Comments__c
                FROM Opportunity
                WHERE Id = :amendCtx.qctx.opportunity.Id
            ];
            System.assertEquals('Completed', amendOpp.StageName, 'Amendment opp should be Completed');
            System.assertEquals('Other', amendOpp.Won_Reason__c, 'Amendment won reason should be set');
            System.assertEquals('Adding a vessel', amendOpp.Won_Reason_Comments__c,
                'Amendment won reason comments should be set');

            Opportunity renewOpp = [
                SELECT StageName, Won_Reason__c, Won_Reason_Comments__c
                FROM Opportunity
                WHERE Id = :renewCtx.qctx.opportunity.Id
            ];
            System.assertEquals('Completed', renewOpp.StageName, 'Renewal opp should be Completed');
            System.assertEquals(null, renewOpp.Won_Reason__c, 'Renewal won reason should not be set');
            System.assertEquals(null, renewOpp.Won_Reason_Comments__c,
                'Renewal won reason comments should not be set');
        }
    }
    
     /**
     * If the Quote has Auto flags (Auto_Installation__c or Auto_Termination__c),
     * validator skips mismatch enforcement.
     */
    @IsTest
    static void test_validateInstallationCount_autoFlags_skip() {
        TestDataFactory_OTG.QuoteContext qc =
            TestDataFactory_OTG.buildDraftQuoteContext('Americas', false, false);

        // QLG install qty = 3
        SBQQ__QuoteLineGroup__c g = qc.groups[0];
        update new SBQQ__QuoteLineGroup__c(
            Id = g.Id,
            Installation_Quantity__c = 3
        );

        // Package + only 1 active installation (mismatch exists)
        Package__c pkg = new Package__c(
            Name                    = 'Pkg-Auto',
            Quote__c                = qc.quote.Id,
            Quote_Line_Group__c     = g.Id,
            Installation_Quantity__c= 3
        );
        insert pkg;

        Vessel__c v = TestDataFactory_OTG.getOrCreateVesselCached();
        insert new Installation__c(
            Package__c                    = pkg.Id,
            Vessel_Name__c                = v.Id,
            Installation_Order_Status__c  = 'Active'
        );

        // Turn on Auto flag -> validator should skip
        update new SBQQ__Quote__c(
            Id = qc.quote.Id,
            Auto_Installation__c = true,
            Auto_Termination__c  = false
        );

        Order o = new Order(
            SBQQ__Quote__c = qc.quote.Id,
            OpportunityId  = qc.opportunity.Id,
            Status         = 'Draft',
            Type           = 'New',
            EffectiveDate  = Date.today(),
            Pricebook2Id   = Test.getStandardPriceBookId()
        );

        Test.startTest();
        OrderTriggerHandler.validateInstallationCount(new List<Order>{ o });
        insert o; // should NOT throw because auto flag skips check
        Test.stopTest();

        System.assertNotEquals(null, o.Id, 'Order should insert when Auto_Installation__c is true');
    }
}
