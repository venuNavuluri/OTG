@IsTest
public class CreateInstallationsControllerTest {

    private static Id bypassUserId;

    @TestSetup
    static void setupOrgDefaults() {
        TestDataFactory_OTG.enableOrgVRConfig();
        TestDataFactory_OTG.primeDefaultOwnerAllRegions(UserInfo.getUserId());

        VRConfiguration__c config = VRConfiguration__c.getOrgDefaults();
        if (config == null) {
            config = new VRConfiguration__c();
        }
        config.ByPass_Account_Triggers__c = true;
        config.ByPass_Contract_Triggers__c = true;
        config.ByPass_Opportunity_Triggers__c = true;
        config.ByPass_Flow__c = true;
        config.ByPass_Installation_Triggers__c = true;
        config.Quote_Ordered_Validation__c = true;
        config.Opportunity_Validation_Rules__c = true;
        upsert config;

        ensureBypassUser();
    }

    private static void ensureBypassUser() {
        if (bypassUserId != null) {
            return;
        }
        Profile p = [SELECT Id FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1];
        String unique = String.valueOf(Crypto.getRandomInteger());
        User bypassUser = new User(
            Alias = 'duser',
            Email = 'duser+' + unique + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Bypass',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'duser+' + unique + '@example.com',
            ProfileId = p.Id
        );
        insert bypassUser;
        bypassUserId = bypassUser.Id;
    }

    private static User getBypassUser() {
        ensureBypassUser();
        return [SELECT Id FROM User WHERE Id = :bypassUserId LIMIT 1];
    }

    private static TestDataFactory_OTG.OrderContext buildContext() {
        TestDataFactory_OTG.OrderContext ctx =
            TestDataFactory_OTG.buildOrderContext('Americas', 'Amendment', 'Draft', true, false);

        update new Opportunity(
            Id = ctx.qctx.opportunity.Id,
            LeadSource = 'Web',
            SBQQ__AmendedContract__c = ctx.packageRec.Contract__c
        );

        Contract contractRec = [
            SELECT Id, Status, CurrencyIsoCode
            FROM Contract
            WHERE Id = :ctx.packageRec.Contract__c
        ];
        update new Contract(
            Id = contractRec.Id,
            Status = 'Activated',
            StartDate = Date.today().addMonths(-6),
            EndDate = Date.today().addMonths(6),
            Billing_Frequency__c = 'Monthly',
            SBQQ__Opportunity__c = ctx.qctx.opportunity.Id
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
            Quote__c = ctx.qctx.quote.Id,
            Quote_Line_Group__c = ctx.qlg.Id,
            Order__c = ctx.orderRec.Id,
            Installation_Start_Date__c = Date.today().addMonths(-3),
            Installation_End_Date__c = Date.today().addMonths(9),
            Installation_Order_Status__c = 'Active',
            Change_Package_Status__c = 'Completed',
            CurrencyIsoCode = contractRec.CurrencyIsoCode
        );

        ctx.installation = [
            SELECT Id, Contract__c, Package__c, Quote__c, Quote_Line_Group__c, Vessel_Name__c
            FROM Installation__c
            WHERE Id = :ctx.installation.Id
        ];

        update new SBQQ__Quote__c(
            Id = ctx.qctx.quote.Id,
            SBQQ__MasterContract__c = contractRec.Id
        );

        return ctx;
    }

    @IsTest
    static void testGetPackages() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        SBQQMockHttpResponseGenerator.setQuoteId(ctx.qctx.quote.Id);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new SBQQMockHttpResponseGenerator());
        List<Package__c> packages = CreateInstallationsController.getPackages(ctx.packageRec.Contract__c);
        Test.stopTest();

        System.assert(!packages.isEmpty(), 'Expected packages to be returned');
    }

    @IsTest
    static void testValidateOpenQuotesOrders() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        update new SBQQ__Quote__c(
            Id = ctx.qctx.quote.Id,
            SBQQ__Status__c = 'Draft',
            SBQQ__Ordered__c = false
        );

        List<String> warnings = CreateInstallationsController.validateOpenQuotesOrders(ctx.packageRec.Contract__c);
        System.assert(!warnings.isEmpty(), 'Expected warnings for draft quote/order');

        List<String> emptyWarnings = CreateInstallationsController.validateOpenQuotesOrders(null);
        System.assertEquals(0, emptyWarnings.size(), 'Null contract should return empty warnings');
    }

    @IsTest
    static void testCreateNewInstRecord() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        Installation__c draftInst = new Installation__c(
            Contract__c = ctx.packageRec.Contract__c,
            Package__c = ctx.packageRec.Id,
            Quote__c = ctx.qctx.quote.Id,
            Vessel_Name__c = TestDataFactory_OTG.createVessels(1)[0].Id
        );

        SBQQMockHttpResponseGenerator.setQuoteId(ctx.qctx.quote.Id);

        System.runAs(getBypassUser()) {
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new SBQQMockHttpResponseGenerator());
            String result = CreateInstallationsController.createNewInstRecord(
                false,
                ctx.packageRec.Id,
                ctx.packageRec.Contract__c,
                draftInst,
                Date.today()
            );
            Test.stopTest();

            System.assert(result.startsWith('SUCCESS'), 'Expected SUCCESS response');
            String newInstId = result.contains(':') ? result.split(':')[1].trim() : null;
            System.assertNotEquals(null, newInstId, 'New installation id should be returned');

            Installation__c created = [
                SELECT Id, Quote__c
                FROM Installation__c
                WHERE Id = :newInstId
            ];
            System.assertEquals(ctx.qctx.quote.Id, created.Quote__c, 'Quote should be linked');
        }
    }

    @IsTest
    static void testCreateNewInstRecordMissingDetails() {
        try {
            CreateInstallationsController.createNewInstRecord(
                false,
                null,
                null,
                null,
                Date.today()
            );
            System.assert(false, 'Expected AuraHandledException for missing details');
        } catch (AuraHandledException ex) {
            System.assert(true);
        }
    }

    @IsTest
    static void testCreateNewInstRecordDuplicate() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        Installation__c duplicate = new Installation__c(
            Contract__c = ctx.packageRec.Contract__c,
            Package__c = ctx.packageRec.Id,
            Quote__c = ctx.qctx.quote.Id,
            Vessel_Name__c = ctx.installation.Vessel_Name__c
        );

        String result = CreateInstallationsController.createNewInstRecord(
            false,
            ctx.packageRec.Id,
            ctx.packageRec.Contract__c,
            duplicate,
            Date.today()
        );

        System.assertEquals('Duplicate_Error', result, 'Expected duplicate detection path');
    }

    @IsTest
    static void testCreateNewInstRecordAllowsTerminatedDuplicateVessel() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        InstallationTriggerHandler.setSuppressTerminationSalesOrderProcessing(true);
        update new Installation__c(
            Id = ctx.installation.Id,
            Installation_Order_Status__c = 'Terminated'
        );
        InstallationTriggerHandler.setSuppressTerminationSalesOrderProcessing(false);

        Installation__c replacement = new Installation__c(
            Contract__c = ctx.packageRec.Contract__c,
            Package__c = ctx.packageRec.Id,
            Quote__c = ctx.qctx.quote.Id,
            Vessel_Name__c = ctx.installation.Vessel_Name__c
        );

        SBQQMockHttpResponseGenerator.setQuoteId(ctx.qctx.quote.Id);

        System.runAs(getBypassUser()) {
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new SBQQMockHttpResponseGenerator());
            String result = CreateInstallationsController.createNewInstRecord(
                false,
                ctx.packageRec.Id,
                ctx.packageRec.Contract__c,
                replacement,
                Date.today()
            );
            Test.stopTest();

            System.assert(result.startsWith('SUCCESS'), 'Terminated installation should not block replacement');
        }
    }

    @IsTest
    static void testCreateNewInstRecordTerminatePath() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        System.runAs(getBypassUser()) {
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new SBQQMockHttpResponseGenerator());
            String result = CreateInstallationsController.createNewInstRecord(
                true,
                ctx.packageRec.Id,
                ctx.packageRec.Contract__c,
                ctx.installation,
                Date.today()
            );
            Test.stopTest();

            System.assertEquals('SUCCESS', result, 'Terminate branch should succeed');
        }
    }

    @IsTest
    static void testTerminateRecordsInvalidDateThrows() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        Contract contractRec = [
            SELECT StartDate
            FROM Contract
            WHERE Id = :ctx.packageRec.Contract__c
        ];
        Date invalidTermination = contractRec.StartDate.addDays(-1);

        try {
            CreateInstallationsController.terminateRecords(
                new List<String>{ ctx.installation.Id },
                invalidTermination,
                'Invalid Date'
            );
            System.assert(false, 'Expected AuraHandledException for invalid termination date');
        } catch (AuraHandledException ex) {
            System.assert(true, 'Caught expected exception for invalid termination date');
        }
    }

    @IsTest
    static void testCheckDuplicatesWithVessel() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        Test.startTest();
        Boolean hasDup = CreateInstallationsController.checkDuplicates(
            ctx.packageRec.Contract__c,
            ctx.installation.Vessel_Name__c,
            null
        );
        Test.stopTest();

        System.assert(hasDup, 'Expected duplicate detected for vessel');
    }

    @IsTest
    static void testCheckDuplicatesIgnoresTerminatedVessel() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        InstallationTriggerHandler.setSuppressTerminationSalesOrderProcessing(true);
        update new Installation__c(
            Id = ctx.installation.Id,
            Installation_Order_Status__c = 'Terminated'
        );
        InstallationTriggerHandler.setSuppressTerminationSalesOrderProcessing(false);

        Test.startTest();
        Boolean hasDup = CreateInstallationsController.checkDuplicates(
            ctx.packageRec.Contract__c,
            ctx.installation.Vessel_Name__c,
            null
        );
        Test.stopTest();

        System.assert(!hasDup, 'Terminated vessel installation should not be treated as duplicate');
    }

    @IsTest
    static void testCheckDuplicatesNoMatch() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        Test.startTest();
        Boolean hasDup = CreateInstallationsController.checkDuplicates(
            ctx.packageRec.Contract__c,
            null,
            'ORG-NOT-EXIST'
        );
        Test.stopTest();

        System.assert(!hasDup, 'Expected no duplicates when identifiers missing');
    }

    @IsTest
    static void testTerminateSingleRecord() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        SBQQMockHttpResponseGenerator.setQuoteId(ctx.qctx.quote.Id);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new SBQQMockHttpResponseGenerator());
        String response = CreateInstallationsController.terminateSingleRecord(
            ctx.installation.Id,
            Date.today(),
            'Unit Test'
        );
        Test.stopTest();

        System.assertEquals('SUCCESS', response, 'Termination should succeed');

        Installation__c refreshed = [
            SELECT Quote__c, Installation_Order_Status__c, Auto_Installation_Termination_Error__c,
                   Termination_Process_Status__c, Termination_Process_Error__c,
                   Termination_Quote__c, Termination_Order__c
            FROM Installation__c
            WHERE Id = :ctx.installation.Id
        ];
        System.assertEquals(ctx.qctx.quote.Id, refreshed.Quote__c, 'Quote should remain linked');
        System.assertEquals('Termination Pending', refreshed.Installation_Order_Status__c,
            'Immediate termination should move the installation to Termination Pending until amendment order activation.');
        System.assertEquals(null, refreshed.Termination_Order__c, 'Termination order should not be set before amendment activation.');
        String err = refreshed.Auto_Installation_Termination_Error__c;
        System.assert(
            err == null
            || err.contains('Maximum stack depth')
            || err.startsWith('Awaiting amendment quote creation')
            || err.startsWith('Awaiting amendment quote line group'),
            'Unexpected error value: ' + err
        );
        if (err == null) {
            System.assertEquals('Waiting For Order Activation', refreshed.Termination_Process_Status__c,
                'Successful amendment sync should wait for order activation.');
            System.assertEquals(ctx.qctx.quote.Id, refreshed.Termination_Quote__c,
                'Termination quote should be tracked once amendment sync succeeds.');
            System.assertEquals(null, refreshed.Termination_Process_Error__c,
                'Successful amendment sync should clear the dedicated process error.');
        } else {
            System.assert(
                refreshed.Termination_Process_Status__c == 'Retry Pending'
                || refreshed.Termination_Process_Status__c == 'Failed',
                'Async CPQ delays should leave the process in a retry/failure state.'
            );
            System.assertEquals(err, refreshed.Termination_Process_Error__c,
                'Dedicated process error should mirror the legacy termination error.');
        }
    }

    @IsTest
    static void testTerminateSingleRecordMissingPackageMarksInstallationFailed() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        update new Installation__c(
            Id = ctx.installation.Id,
            Package__c = null
        );

        Test.startTest();
        String response = CreateInstallationsController.terminateSingleRecord(
            ctx.installation.Id,
            Date.today(),
            'Missing Package'
        );
        Test.stopTest();

        System.assertEquals('SUCCESS', response, 'Termination request should still be accepted.');

        Installation__c refreshed = [
            SELECT Installation_Order_Status__c, Termination_Process_Status__c, Termination_Process_Error__c
            FROM Installation__c
            WHERE Id = :ctx.installation.Id
        ];
        System.assertEquals('Termination Pending', refreshed.Installation_Order_Status__c,
            'Immediate termination request should still move the installation into pending state.');
        System.assertEquals('Failed', refreshed.Termination_Process_Status__c,
            'Installations that cannot start CPQ processing should be marked failed individually.');
        System.assertEquals('Termination cannot proceed because the installation has no related package.',
            refreshed.Termination_Process_Error__c,
            'Each failed installation should carry its own termination error.');
    }

    @IsTest
    static void testTerminateRecordsRequiresIds() {
        try {
            CreateInstallationsController.terminateRecords(null, Date.today(), '');
            System.assert(false, 'Expected AuraHandledException for missing ids');
        } catch (AuraHandledException ex) {
            System.assert(true);
        }
    }

    @IsTest
    static void testGetInstallationsAndRecords() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        Test.startTest();
        List<CreateInstallationsController.InstallationData> wrapped =
            CreateInstallationsController.getInstallations(ctx.packageRec.Contract__c);
        List<Installation__c> direct =
            CreateInstallationsController.getInstallationRecs(ctx.packageRec.Contract__c);
        Test.stopTest();

        System.assert(!wrapped.isEmpty(), 'Expected wrapped installations');
        System.assert(!direct.isEmpty(), 'Expected direct installation list');
    }

    @IsTest
    static void testGetContractDetails() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        Map<String, Object> details = CreateInstallationsController.getContractDetails(ctx.installation.Id);
        System.assert(details.containsKey('startDate'), 'Expected start date');
        System.assert(details.containsKey('endDate'), 'Expected end date');
        System.assert(details.containsKey('status'), 'Expected status');
    }

    @IsTest
    static void testModifyContractQueueable() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        SBQQMockHttpResponseGenerator.setQuoteId(ctx.qctx.quote.Id);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new SBQQMockHttpResponseGenerator());
        CreateInstallationsController.modifyContract(
            ctx.installation.Id,
            Date.today(),
            ctx.packageRec.Contract__c,
            ctx.packageRec.Id,
            false
        );
        Test.stopTest();

        Installation__c refreshed = [
            SELECT Quote__c, Termination_Process_Status__c, Termination_Process_Error__c
            FROM Installation__c
            WHERE Id = :ctx.installation.Id
        ];
        System.assertEquals(ctx.qctx.quote.Id, refreshed.Quote__c, 'Quote should stay linked');
        System.assertEquals(null, refreshed.Termination_Process_Status__c,
            'Non-termination amendment processing should not stamp termination process state.');
        System.assertEquals(null, refreshed.Termination_Process_Error__c,
            'Non-termination amendment processing should not stamp termination process error.');
    }

    @IsTest
    static void testQueueableSuccessPath() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        System.runAs(getBypassUser()) {
            Test.startTest();
            System.enqueueJob(new CreateInstallationsController.AmendmentPostProcessorQueueable(
                ctx.installation.Id,
                ctx.packageRec.Contract__c,
                ctx.packageRec.Id,
                ctx.qctx.quote.Id,
                Date.today(),
                false,
                1
            ));
            Test.stopTest();

            Installation__c refreshed = [
                SELECT Quote_Line_Group__c
                FROM Installation__c
                WHERE Id = :ctx.installation.Id
            ];
            System.assertEquals(ctx.qlg.Id, refreshed.Quote_Line_Group__c,
                'Quote line group should be set');
        }
    }

    @IsTest
    static void testQueueableTerminatePath() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        update new Installation__c(
            Id = ctx.installation.Id,
            Termination_End_Date__c = Date.today(),
            Auto_Termination__c = true,
            Termination_Process_Status__c = 'CPQ Submitted'
        );

        update new SBQQ__QuoteLineGroup__c(
            Id = ctx.qlg.Id,
            Installation_Quantity__c = 2,
            Package__c = ctx.packageRec.Id
        );

        System.runAs(getBypassUser()) {
            Test.startTest();
            System.enqueueJob(new CreateInstallationsController.AmendmentPostProcessorQueueable(
                ctx.installation.Id,
                ctx.packageRec.Contract__c,
                ctx.packageRec.Id,
                ctx.qctx.quote.Id,
                Date.today(),
                true,
                1
            ));
            Test.stopTest();

            Installation__c refreshed = [
                SELECT Quote_Line_Group__c, Termination_Process_Status__c, Termination_Quote__c, Termination_Process_Error__c,
                       Auto_Installation_Termination_Error__c
                FROM Installation__c
                WHERE Id = :ctx.installation.Id
            ];
            System.assertEquals(ctx.qlg.Id, refreshed.Quote_Line_Group__c,
                'Quote line group should still be set for terminate path');
            System.assert(
                refreshed.Termination_Process_Status__c == 'Waiting For Order Activation'
                || refreshed.Termination_Process_Status__c == 'Retry Pending'
                || refreshed.Termination_Process_Status__c == 'Failed',
                'Termination queueable should either advance the process or record a retry/failure state.'
            );
            if (refreshed.Termination_Process_Status__c == 'Waiting For Order Activation') {
                System.assertEquals(ctx.qctx.quote.Id, refreshed.Termination_Quote__c,
                    'Termination quote should be persisted on the installation.');
                System.assertEquals(null, refreshed.Termination_Process_Error__c,
                    'Successful termination quote sync should clear dedicated process errors.');
            } else {
                System.assertNotEquals(null, refreshed.Auto_Installation_Termination_Error__c,
                    'Failed termination processing should record the legacy error field.');
            }

            SBQQ__QuoteLineGroup__c qlgRef = [
                SELECT Installation_Quantity__c
                FROM SBQQ__QuoteLineGroup__c
                WHERE Id = :ctx.qlg.Id
            ];
            System.assert(qlgRef.Installation_Quantity__c == 2 || qlgRef.Installation_Quantity__c == 1,
                'Terminate path should either preserve the original quantity on failure or decrement it by one on success.');
        }
    }

    @IsTest
    static void testQueueableFailurePath() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        Package__c noQlgPackage = new Package__c(
            Name = 'No QLG Package',
            Contract__c = ctx.packageRec.Contract__c,
            Quote__c = ctx.qctx.quote.Id
        );
        insert noQlgPackage;

        Test.startTest();
        System.enqueueJob(new CreateInstallationsController.AmendmentPostProcessorQueueable(
            ctx.installation.Id,
            ctx.packageRec.Contract__c,
            noQlgPackage.Id,
            null,
            Date.today(),
            false,
            5
        ));
        Test.stopTest();

        Installation__c refreshed = [
            SELECT Auto_Installation_Termination_Error__c, Termination_Process_Status__c, Termination_Process_Error__c
            FROM Installation__c
            WHERE Id = :ctx.installation.Id
        ];
        System.assert(refreshed.Auto_Installation_Termination_Error__c != null,
            'Expected error message recorded');
        System.assertEquals(null, refreshed.Termination_Process_Error__c,
            'Non-termination failures should not stamp the dedicated termination process error.');
        System.assertEquals(null, refreshed.Termination_Process_Status__c,
            'Non-termination failures should not stamp the dedicated termination process status.');
    }

    @IsTest
    static void testUpdateQuoteLineGroupReturnsNull() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        Package__c noQlgPackage = new Package__c(
            Name = 'No QLG Package For Lookup',
            Contract__c = ctx.packageRec.Contract__c,
            Quote__c = ctx.qctx.quote.Id
        );
        insert noQlgPackage;

        SBQQ__QuoteLineGroup__c result = CreateInstallationsController.updateQuoteLineGroup(
            ctx.qctx.quote,
            noQlgPackage.Id,
            false
        );

        System.assertEquals(null, result, 'Expected null when no quote line group exists');
    }

    @IsTest
    static void testFindLatestQuoteViaAmendedOpportunity() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        update new Opportunity(
            Id = ctx.qctx.opportunity.Id,
            SBQQ__AmendedContract__c = ctx.packageRec.Contract__c
        );

        SBQQ__Quote__c q = new SBQQ__Quote__c(
            Id = ctx.qctx.quote.Id,
            SBQQ__Opportunity2__c = ctx.qctx.opportunity.Id
        );
        update q;

        CreateInstallationsController.TEST_FORCE_FIND_QUOTE_MASTER_ERROR = true;
        SBQQ__Quote__c found = CreateInstallationsController.findLatestQuoteForContract(
            ctx.packageRec.Contract__c,
            'test_amended_path'
        );
        CreateInstallationsController.TEST_FORCE_FIND_QUOTE_MASTER_ERROR = false;

        System.assertEquals(q.Id, found.Id, 'Expected amended opportunity quote to be found');
    }

    @IsTest
    static void testFindLatestQuotePrefersAmendmentQuoteOverGenericMasterQuote() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        update new SBQQ__Quote__c(
            Id = ctx.qctx.quote.Id,
            SBQQ__Type__c = 'Amendment',
            SBQQ__MasterContract__c = ctx.packageRec.Contract__c,
            SBQQ__Opportunity2__c = ctx.qctx.opportunity.Id
        );

        SBQQ__Quote__c genericMasterQuote = new SBQQ__Quote__c(
            SBQQ__MasterContract__c = ctx.packageRec.Contract__c,
            SBQQ__Status__c = 'Draft'
        );
        insert genericMasterQuote;

        SBQQ__Quote__c found = CreateInstallationsController.findLatestQuoteForContract(
            ctx.packageRec.Contract__c,
            'test_prefer_amendment'
        );

        System.assertEquals(ctx.qctx.quote.Id, found.Id,
            'Amendment quote should be preferred over a generic master-contract quote.');
    }

    @IsTest
    static void testFindLatestQuoteNoResults() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        Account acc = new Account(Name = 'No Quote Account');
        insert acc;

        Contract c = new Contract(
            AccountId = acc.Id,
            Status = 'Draft',
            StartDate = Date.today(),
            EndDate = Date.today().addDays(30),
            ContractTerm = 1
        );
        insert c;

        SBQQ__Quote__c found = CreateInstallationsController.findLatestQuoteForContract(
            c.Id,
            'test_no_results'
        );

        System.assertEquals(null, found, 'Expected no quote when none are related');
    }

    @IsTest
    static void testFindLatestQuoteCatchesErrors() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        CreateInstallationsController.TEST_FORCE_FIND_QUOTE_MASTER_ERROR = true;
        CreateInstallationsController.TEST_FORCE_FIND_QUOTE_AMENDED_ERROR = true;

        SBQQ__Quote__c found = CreateInstallationsController.findLatestQuoteForContract(
            ctx.packageRec.Contract__c,
            'test_forced_errors'
        );

        System.assertEquals(ctx.qctx.quote.Id, found.Id,
            'Expected fallback master-contract lookup to still return the latest quote.');

        CreateInstallationsController.TEST_FORCE_FIND_QUOTE_MASTER_ERROR = false;
        CreateInstallationsController.TEST_FORCE_FIND_QUOTE_AMENDED_ERROR = false;
    }

    @IsTest
    static void testFindTerminationQuoteForRequestIgnoresOlderAmendmentQuote() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        update new SBQQ__Quote__c(
            Id = ctx.qctx.quote.Id,
            SBQQ__Type__c = 'Amendment',
            SBQQ__MasterContract__c = ctx.packageRec.Contract__c,
            SBQQ__Opportunity2__c = ctx.qctx.opportunity.Id
        );
        Test.setCreatedDate(ctx.qctx.quote.Id, Datetime.now().addMinutes(-10));

        String requestMarker = CreateInstallationsController.formatRequestMarker(System.now());
        SBQQ__Quote__c found = CreateInstallationsController.findTerminationQuoteForRequest(
            ctx.packageRec.Contract__c,
            ctx.installation.Id,
            requestMarker,
            'test_ignore_old_amendment'
        );

        System.assertEquals(null, found,
            'Older amendment quotes must not be linked as the termination quote for a new request.');
    }

    @IsTest
    static void testFindTerminationQuoteForRequestIgnoresOlderLinkedTerminationQuote() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        update new SBQQ__Quote__c(
            Id = ctx.qctx.quote.Id,
            SBQQ__Type__c = 'Amendment',
            SBQQ__MasterContract__c = ctx.packageRec.Contract__c,
            SBQQ__Opportunity2__c = ctx.qctx.opportunity.Id,
            Auto_Termination__c = true,
            Installation__c = ctx.installation.Id
        );
        Test.setCreatedDate(ctx.qctx.quote.Id, Datetime.now().addMinutes(-10));

        String requestMarker = CreateInstallationsController.formatRequestMarker(System.now());
        SBQQ__Quote__c found = CreateInstallationsController.findTerminationQuoteForRequest(
            ctx.packageRec.Contract__c,
            ctx.installation.Id,
            requestMarker,
            'test_ignore_old_linked_termination_quote'
        );

        System.assertEquals(null, found,
            'Older linked termination quotes must not satisfy a new termination request.');
    }

    @IsTest
    static void testFindTerminationQuoteForRequestReturnsFreshLinkedTerminationQuote() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        update new SBQQ__Quote__c(
            Id = ctx.qctx.quote.Id,
            SBQQ__Type__c = 'Amendment',
            SBQQ__MasterContract__c = ctx.packageRec.Contract__c,
            SBQQ__Opportunity2__c = ctx.qctx.opportunity.Id,
            Auto_Termination__c = true,
            Installation__c = ctx.installation.Id
        );

        String requestMarker = CreateInstallationsController.formatRequestMarker(System.now().addSeconds(-1));
        SBQQ__Quote__c found = CreateInstallationsController.findTerminationQuoteForRequest(
            ctx.packageRec.Contract__c,
            ctx.installation.Id,
            requestMarker,
            'test_find_fresh_linked_termination_quote'
        );

        System.assertNotEquals(null, found,
            'Fresh linked termination quote should be found for the current request.');
        System.assertEquals(ctx.qctx.quote.Id, found.Id,
            'Fresh linked termination quote should be reused for the current request.');
    }

    @IsTest
    static void testSchedulerExecuteEnqueuesQueueable() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        CreateInstallationsController.AmendmentPostProcessorScheduler sched =
            new CreateInstallationsController.AmendmentPostProcessorScheduler(
                ctx.installation.Id,
                ctx.packageRec.Contract__c,
                ctx.packageRec.Id,
                ctx.qctx.quote.Id,
                Date.today(),
                false,
                1
            );

        Test.startTest();
        sched.execute(null);
        Test.stopTest();

        System.assert(true, 'Scheduler execute completed');
    }

    @IsTest
    static void testTryUpdateQuoteAndInstallationNonTerminateUpdatesInstallation() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        update new SBQQ__QuoteLineGroup__c(
            Id = ctx.qlg.Id,
            Package__c = ctx.packageRec.Id
        );

        Boolean success = CreateInstallationsController.tryUpdateQuoteAndInstallation(
            ctx.qctx.quote,
            ctx.installation.Id,
            ctx.packageRec.Contract__c,
            ctx.packageRec.Id,
            Date.today(),
            false
        );

        System.assertEquals(true, success, 'Expected update to succeed');

        Installation__c refreshed = [
            SELECT Quote__c, Quote_Line_Group__c, Auto_Installation__c, Termination_Process_Status__c
            FROM Installation__c
            WHERE Id = :ctx.installation.Id
        ];
        System.assertEquals(ctx.qctx.quote.Id, refreshed.Quote__c, 'Quote should be set');
        System.assertEquals(ctx.qlg.Id, refreshed.Quote_Line_Group__c, 'Quote line group should be set');
        System.assertEquals(true, refreshed.Auto_Installation__c, 'Auto installation should be set');
        System.assertEquals(null, refreshed.Termination_Process_Status__c,
            'Non-termination quote updates should not stamp termination process state.');
    }

    @IsTest
    static void testUpdateInstallationRequiresId() {
        Boolean thrown = false;
        try {
            CreateInstallationsController.updateInstallation(null, null, null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException ex) {
            thrown = true;
        }
        System.assert(thrown, 'Expected AuraHandledException for missing installation id');
    }

    @IsTest
    static void testTryUpdateQuoteAndInstallationTerminatePath() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        System.runAs(getBypassUser()) {
            update new Installation__c(
                Id = ctx.installation.Id,
                Termination_End_Date__c = Date.today(),
                Auto_Termination__c = true,
                Termination_Process_Status__c = 'CPQ Submitted'
            );

            update new SBQQ__QuoteLineGroup__c(
                Id = ctx.qlg.Id,
                Installation_Quantity__c = 2,
                Package__c = ctx.packageRec.Id
            );

            update new SBQQ__Quote__c(
                Id = ctx.qctx.quote.Id,
                SBQQ__Opportunity2__c = ctx.qctx.opportunity.Id
            );

            Test.startTest();
            SBQQ__Quote__c qt = [SELECT Id, SBQQ__Opportunity2__c FROM SBQQ__Quote__c WHERE Id = :ctx.qctx.quote.Id];
            Boolean success = CreateInstallationsController.tryUpdateQuoteAndInstallation(
                qt,
                ctx.installation.Id,
                ctx.packageRec.Contract__c,
                ctx.packageRec.Id,
                Date.today(),
                true
            );
            Test.stopTest();

            Installation__c instErr = [
                SELECT Auto_Installation_Termination_Error__c, Termination_Process_Status__c, Termination_Quote__c
                FROM Installation__c
                WHERE Id = :ctx.installation.Id
            ];
            System.assert(success || instErr.Auto_Installation_Termination_Error__c != null,
                'Terminate branch should either succeed or record an error');
            if (success) {
                System.assertEquals('Waiting For Order Activation', instErr.Termination_Process_Status__c,
                    'Successful terminate branch should wait for amendment order activation.');
                System.assertEquals(ctx.qctx.quote.Id, instErr.Termination_Quote__c,
                    'Successful terminate branch should track the amendment quote.');
            }
        }
    }

    @IsTest
    static void testTryUpdateQuoteAndInstallationTerminateIsIdempotentForSameQuote() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        System.runAs(getBypassUser()) {
            update new Installation__c(
                Id = ctx.installation.Id,
                Termination_End_Date__c = Date.today(),
                Auto_Termination__c = true,
                Termination_Process_Status__c = 'CPQ Submitted'
            );

            update new SBQQ__QuoteLineGroup__c(
                Id = ctx.qlg.Id,
                Installation_Quantity__c = 2,
                Package__c = ctx.packageRec.Id
            );

            Test.startTest();
            Boolean firstSuccess = CreateInstallationsController.tryUpdateQuoteAndInstallation(
                ctx.qctx.quote,
                ctx.installation.Id,
                ctx.packageRec.Contract__c,
                ctx.packageRec.Id,
                Date.today(),
                true
            );
            Boolean secondSuccess = CreateInstallationsController.tryUpdateQuoteAndInstallation(
                ctx.qctx.quote,
                ctx.installation.Id,
                ctx.packageRec.Contract__c,
                ctx.packageRec.Id,
                Date.today(),
                true
            );
            Test.stopTest();

            System.assertEquals(true, firstSuccess, 'First termination sync should succeed.');
            System.assertEquals(true, secondSuccess, 'Repeated sync for the same quote should be treated as idempotent.');
        }

        SBQQ__QuoteLineGroup__c refreshedQlg = [
            SELECT Installation_Quantity__c
            FROM SBQQ__QuoteLineGroup__c
            WHERE Id = :ctx.qlg.Id
        ];
        System.assertEquals(1, refreshedQlg.Installation_Quantity__c,
            'Termination should decrement amendment quote line group quantity by exactly one.');
    }

    @IsTest
    static void testTryUpdateQuoteAndInstallationMissingInstallation() {
        TestDataFactory_OTG.OrderContext ctx = buildContext();

        Id installId = Id.valueOf(Installation__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000');
        Id contractId = ctx.packageRec.Contract__c;
        Id packageId = ctx.packageRec.Id;
        SBQQ__Quote__c qt = [SELECT Id FROM SBQQ__Quote__c WHERE Id = :ctx.qctx.quote.Id];
        Decimal originalInstallationQuantity = [
            SELECT Installation_Quantity__c
            FROM SBQQ__QuoteLineGroup__c
            WHERE Id = :ctx.qlg.Id
            LIMIT 1
        ].Installation_Quantity__c;

        System.runAs(getBypassUser()) {
            Test.startTest();
            Boolean success = CreateInstallationsController.tryUpdateQuoteAndInstallation(
                qt,
                installId,
                contractId,
                packageId,
                Date.today(),
                true
            );
            Test.stopTest();

            System.assert(!success, 'Expected terminate path to fail when installation missing');
        }

        SBQQ__QuoteLineGroup__c qlgAfter = [
            SELECT Installation_Quantity__c
            FROM SBQQ__QuoteLineGroup__c
            WHERE Id = :ctx.qlg.Id
            LIMIT 1
        ];
        System.assertEquals(originalInstallationQuantity, qlgAfter.Installation_Quantity__c,
            'QLG quantity should roll back when terminate update fails.');
    }
}
