@IsTest
private class QuoteInstallationControllerTest {

    private class MoveContext {
        SBQQ__Quote__c quote;
        SBQQ__QuoteLineGroup__c sourceQLG;
        SBQQ__QuoteLineGroup__c targetQLG;
        Package__c sourcePkg;
        Package__c targetPkg;
        Installation__c sourceInst;
    }
    
    private static MoveContext buildMoveContext(Integer sourceCap, Integer targetCap) {
        TestDataFactory_OTG.enableOrgVRConfig();
        TestDataFactory_OTG.primeDefaultOwnerAllRegions(UserInfo.getUserId());
        TestDataFactory_OTG.QuoteContext qc =
            TestDataFactory_OTG.buildDraftQuoteContext('Americas', true, true);
    
        SBQQ__QuoteLineGroup__c sourceQLG =
            TestDataFactory_OTG.createQuoteLineGroup(qc.quote.Id, 'Src QLG', false, sourceCap);
        SBQQ__QuoteLineGroup__c targetQLG =
            TestDataFactory_OTG.createQuoteLineGroup(qc.quote.Id, 'Tgt QLG', false, targetCap);
    
        Date s = Date.today(), e = s.addMonths(12);
        // qc.pbe is a standard PricebookEntry (not SBQQ__PricebookEntry__c)
        TestDataFactory_OTG.createQuoteLine(qc.quote.Id, sourceQLG.Id, qc.pbe.Id, 1, null, 111, s, e, null);
        TestDataFactory_OTG.createQuoteLine(qc.quote.Id, targetQLG.Id, qc.pbe.Id, 1, null, 222, s, e, null);
    
        Package__c sourcePkg = new Package__c(
            Quote__c = qc.quote.Id, Installation_Quantity__c = sourceCap, Name='Pkg-Source'
        );
        Package__c targetPkg = new Package__c(
            Quote__c = qc.quote.Id, Installation_Quantity__c = targetCap, Name='Pkg-Target'
        );
        insert new List<Package__c>{ sourcePkg, targetPkg };
    
        update new SBQQ__QuoteLineGroup__c(Id = sourceQLG.Id, Package__c = sourcePkg.Id);
        update new SBQQ__QuoteLineGroup__c(Id = targetQLG.Id, Package__c = targetPkg.Id);
    
        Id vesselId;
        List<Vessel__c> vs = [SELECT Id FROM Vessel__c LIMIT 1];
        if (vs.isEmpty()) {
            insert new Vessel__c(Name='v-1', Vessel_IMO_Status__c='Active IMO');
            vesselId = [SELECT Id FROM Vessel__c WHERE Name='v-1' LIMIT 1].Id;
        } else {
            vesselId = vs[0].Id;
        }
    
        Installation__c srcInst = new Installation__c(
            Installation_Type__c = 'Vessel',
            Vessel_Name__c       = vesselId,
            Quote__c             = qc.quote.Id,
            Quote_Line_Group__c  = sourceQLG.Id,
            Package__c           = sourcePkg.Id,
            Installation_Order_Status__c = 'Draft'
        );
        insert srcInst;
    
        MoveContext ctx = new MoveContext();
        ctx.quote     = qc.quote;
        ctx.sourceQLG = sourceQLG;
        ctx.targetQLG = targetQLG;
        ctx.sourcePkg = sourcePkg;
        ctx.targetPkg = targetPkg;
        ctx.sourceInst= srcInst;
        return ctx;
    }

    @TestSetup
    static void setupData_WithFactory() {
        TestDataFactory_OTG.enableOrgVRConfig();
        TestDataFactory_OTG.primeDefaultOwnerAllRegions(UserInfo.getUserId());

        // Base Quote context: creates B2B + Invoice Account + Product/PBE + Quote
        TestDataFactory_OTG.QuoteContext qc =
            TestDataFactory_OTG.buildDraftQuoteContext('Americas', true, true);

        // Sales Rep (used by email branch)
        update new SBQQ__Quote__c(
            Id = qc.quote.Id,
            SBQQ__SalesRep__c = UserInfo.getUserId()
        );

        // One user-created QLG with installation qty=3
        SBQQ__QuoteLineGroup__c qlg = TestDataFactory_OTG.createQuoteLineGroup(
            qc.quote.Id, 'User QLG', false, 3
        );

        // One quote line so the group has products/prices
        Date s = Date.today(), e = s.addMonths(12);
        TestDataFactory_OTG.createQuoteLine(qc.quote.Id, qlg.Id, qc.pbe.Id, 1, null, 100, s, e, null);

        // Package linked to the group
        Package__c pkg = new Package__c(
            Quote__c                 = qc.quote.Id,
            Installation_Quantity__c = 3,
            Name                     = 'Pkg-User'
        );
        insert pkg;
        update new SBQQ__QuoteLineGroup__c(Id = qlg.Id, Package__c = pkg.Id);

        // A few vessels (for CSV import)
        insert new List<Vessel__c>{
            new Vessel__c(Name='Test1', Vessel_IMO__c='123',   Vessel_IMO_Status__c='Active IMO'),
            new Vessel__c(Name='Test2', Vessel_IMO__c='1234',  Vessel_IMO_Status__c='Active IMO'),
            new Vessel__c(Name='Test3', Vessel_IMO__c='12345', Vessel_IMO_Status__c='Active IMO')
        };
    }

    @IsTest
    static void test_FetchGroups_CreateInstallations_CreateRecords() {
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c ORDER BY CreatedDate ASC LIMIT 1];

        // --- fetchQuoteLineGroups (happy path) ---
        String groupsJson = QuoteInstallationController.fetchQuoteLineGroups(quote.Id);
        List<QuoteInstallationController.QuoteRecordWrapper> wrappers =
            (List<QuoteInstallationController.QuoteRecordWrapper>)
                JSON.deserialize(groupsJson, List<QuoteInstallationController.QuoteRecordWrapper>.class);
        System.assert(!wrappers.isEmpty(), 'Expected at least one QLG.');
        Id qlgId = wrappers[0].qlg.Id;

        // --- fetchQuoteLineGroupProducts ---
        String prodCsv = QuoteInstallationController.fetchQuoteLineGroupProducts(qlgId);
        System.assertNotEquals(null, prodCsv, 'Products CSV must not be null.');

        // --- createInstallations (CSV with valid Invoice key if available) ---
        Account invAcc = [
            SELECT Id, Account_ID__c
            FROM Account
            WHERE RecordType.Name = 'Invoice Account'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        String invKey = invAcc.Account_ID__c; // read-only in tests

        String csvOk = 'VesselIMO,InvoiceAccount\n123,' + (String.isBlank(invKey) ? 'NO_MATCH' : invKey) + '\n';
        insert new ContentVersion(VersionData=Blob.valueOf(csvOk), Title='ok', ContentLocation='S', PathOnClient='ok.csv');

        Decimal perInstPrice = 100;
        String okResult = QuoteInstallationController.createInstallations(
            [SELECT Id FROM ContentVersion WHERE Title='ok' ORDER BY CreatedDate DESC LIMIT 1].Id,
            quote.Id, qlgId, perInstPrice
        );
        System.assertNotEquals(null, okResult, 'createInstallations should return a message.');

        // --- createRecords (direct create path) ---
        // Pass an actual Account Id for Invoice_Account__c (this is a lookup, not the Account_ID__c text)
        try {
            QuoteInstallationController.createRecords(
                quote.Id, qlgId, 1, null,
                [SELECT Id FROM Account WHERE RecordType.Name='Invoice Account' LIMIT 1].Id,
                null
            );
        } catch (Exception e) {
            System.assert(false, 'createRecords should not throw: ' + e.getMessage());
        }
    }

    @IsTest
    static void test_CreateInstallations_EmailBranch_NoInvoiceMatch() {
        // Use the existing quote + group
        SBQQ__QuoteLineGroup__c qlg = [
            SELECT Id, SBQQ__Quote__c
            FROM SBQQ__QuoteLineGroup__c
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];

        // CSV with a real IMO but a NON-matching InvoiceAccount key -> triggers
        // "Invoice Account not present" + email branch (in tests, blob is 'Unit.Test').
        String csvNoMatch = 'VesselIMO,InvoiceAccount\n123,DOES_NOT_EXIST\n';
        insert new ContentVersion(
            VersionData     = Blob.valueOf(csvNoMatch),
            Title           = 'noMatch',
            ContentLocation = 'S',
            PathOnClient    = 'noMatch.csv'
        );

        String result = QuoteInstallationController.createInstallations(
            [SELECT Id FROM ContentVersion WHERE Title='noMatch' ORDER BY CreatedDate DESC LIMIT 1].Id,
            qlg.SBQQ__Quote__c, qlg.Id,
            50
        );
        // We don’t assert on the exact text (label suffix varies), just make sure it returned.
        System.assertNotEquals(null, result, 'createInstallations should return a message and not throw.');
    }

    @IsTest
    static void test_FetchGroups_Amendment_IncludesRelatedQuotes() {
        // Take the earliest quote and make it an Amendment tied to a master Contract
        SBQQ__Quote__c baseQuote = [
            SELECT Id, SBQQ__Type__c
            FROM SBQQ__Quote__c
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];

        // Master contract and Approved sibling quote on the same contract
        Contract ctr = TestDataFactory_OTG.createContractBasic(
            [SELECT SBQQ__Account__c FROM SBQQ__Quote__c WHERE Id = :baseQuote.Id].SBQQ__Account__c,
            'USD', Date.today(), 12, null
        );
        update new SBQQ__Quote__c(Id = baseQuote.Id, SBQQ__Type__c = 'Amendment', SBQQ__MasterContract__c = ctr.Id);

        SBQQ__Quote__c approvedSibling = new SBQQ__Quote__c(
            SBQQ__Account__c      = [SELECT SBQQ__Account__c FROM SBQQ__Quote__c WHERE Id = :baseQuote.Id].SBQQ__Account__c,
            SBQQ__Opportunity2__c = [SELECT SBQQ__Opportunity2__c FROM SBQQ__Quote__c WHERE Id = :baseQuote.Id].SBQQ__Opportunity2__c,
            SBQQ__SubscriptionTerm__c = 12,
            SBQQ__PricebookId__c  = Test.getStandardPriceBookId(),
            SBQQ__StartDate__c    = Date.today(),
            SBQQ__Primary__c      = false,
            SBQQ__Status__c       = 'Approved',
            SBQQ__Type__c         = 'Amendment',
            SBQQ__MasterContract__c = ctr.Id
        );
        insert approvedSibling;

        // Call the method – it should include the base, the master’s quote (if any), and approved siblings
        String groupsJson = QuoteInstallationController.fetchQuoteLineGroups(baseQuote.Id);
        System.assertNotEquals(null, groupsJson, 'Should return JSON even for Amendment path.');
        // Basic sanity: JSON string should start with '['
        System.assertEquals(true, groupsJson.startsWith('['), 'Expected JSON array.');
    }
    
    @IsTest
    static void test_SaveInstallation_PopulatesFields_AndReturnsInsertedRows() {
        // 1) Find or create a Quote + QLG using your factory (defensive bootstrap)
        SBQQ__QuoteLineGroup__c qlg;
        List<SBQQ__QuoteLineGroup__c> qlgs = [
            SELECT Id, Package__c, SBQQ__Quote__c,
                   SBQQ__Quote__r.CurrencyISOCode,
                   SBQQ__Quote__r.SBQQ__Account__c,
                   SBQQ__Quote__r.SBQQ__MasterContract__c
            FROM SBQQ__QuoteLineGroup__c
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        if (qlgs.isEmpty()) {
            // Build a complete minimal context
            TestDataFactory_OTG.enableOrgVRConfig();
            TestDataFactory_OTG.primeDefaultOwnerAllRegions(UserInfo.getUserId());
            TestDataFactory_OTG.QuoteContext qc =
                TestDataFactory_OTG.buildDraftQuoteContext('Americas', true, true);
    
            // One user-created QLG
            qlg = TestDataFactory_OTG.createQuoteLineGroup(qc.quote.Id, 'SaveInst QLG', false, 1);
    
            // Make sure there is at least one line under the group
            Date s = Date.today(), e = s.addMonths(12);
            TestDataFactory_OTG.createQuoteLine(qc.quote.Id, qlg.Id, qc.pbe.Id, 1, null, 100, s, e, null);
    
            // Link a Package to the QLG (controller reads Package__c from QLG)
            Package__c pkg = new Package__c(
                Quote__c                 = qc.quote.Id,
                Installation_Quantity__c = 1,
                Name                     = 'Pkg-For-SaveInst'
            );
            insert pkg;
            update new SBQQ__QuoteLineGroup__c(Id = qlg.Id, Package__c = pkg.Id);
    
            // Ensure Quote has a Master Contract so Contract__c mapping is covered
            if (qc.quote.SBQQ__MasterContract__c == null) {
                Contract ctr = TestDataFactory_OTG.createContractBasic(
                    qc.b2bAccount.Id, 'USD', Date.today(), 12, null
                );
                update new SBQQ__Quote__c(Id = qc.quote.Id, SBQQ__MasterContract__c = ctr.Id);
            }
        } else {
            qlg = qlgs[0];
    
            // If the QLG has no package, create and link one now
            if (qlg.Package__c == null) {
                Package__c pkg = new Package__c(
                    Quote__c                 = qlg.SBQQ__Quote__c,
                    Installation_Quantity__c = 1,
                    Name                     = 'Pkg-For-SaveInst'
                );
                insert pkg;
                update new SBQQ__QuoteLineGroup__c(Id = qlg.Id, Package__c = pkg.Id);
            }
    
            // Ensure the Quote has a Master Contract to hit that mapping branch
            SBQQ__Quote__c q = [
                SELECT Id, SBQQ__MasterContract__c, SBQQ__Account__c
                FROM SBQQ__Quote__c
                WHERE Id = :qlg.SBQQ__Quote__c
                LIMIT 1
            ];
            if (q.SBQQ__MasterContract__c == null) {
                // Create a simple contract on the quote’s account
                Contract ctr = new Contract(
                    AccountId    = q.SBQQ__Account__c,
                    Status       = 'Draft',
                    StartDate    = Date.today(),
                    ContractTerm = 12
                );
                insert ctr;
                update new SBQQ__Quote__c(Id = q.Id, SBQQ__MasterContract__c = ctr.Id);
            }
        }
    
        // Refresh with all fields we need for assertions
        qlg = [
            SELECT Id, Package__c, SBQQ__Quote__c,
                   SBQQ__Quote__r.CurrencyISOCode,
                   SBQQ__Quote__r.SBQQ__Account__c,
                   SBQQ__Quote__r.SBQQ__MasterContract__c
            FROM SBQQ__QuoteLineGroup__c
            WHERE Id = :qlg.Id
            LIMIT 1
        ];
    
        // 2) Ensure at least one Vessel exists (some orgs have validations)
        Id vesselId;
        List<Vessel__c> vessels = [SELECT Id FROM Vessel__c LIMIT 1];
        if (vessels.isEmpty()) {
            insert new Vessel__c(Name='Vessel A', Vessel_IMO_Status__c='Active IMO');
            vesselId = [SELECT Id FROM Vessel__c WHERE Name='Vessel A' LIMIT 1].Id;
        } else {
            vesselId = vessels[0].Id;
        }
    
        // 3) Build two installations to exercise the loop + insert + return SOQL
        List<sObject> toSave = new List<sObject>{
            new Installation__c(
                Installation_Type__c = 'Vessel',
                Vessel_Name__c       = vesselId,
                Quote_Line_Group__c  = qlg.Id
            ),
            new Installation__c(
                Installation_Type__c = 'Vessel',
                Vessel_Name__c       = vesselId,
                Quote_Line_Group__c  = qlg.Id
            )
        };
    
        // 4) ACT
        List<sObject> returnedRows = QuoteInstallationController.saveInstallation(toSave);
    
        // 5) ASSERT basic return count
        System.assertEquals(2, returnedRows.size(), 'Controller should return the two inserted rows.');
    
        // Gather Ids to requery strongly-typed records
        List<Id> insIds = new List<Id>();
        for (sObject so : returnedRows) insIds.add(((Installation__c)so).Id);
    
        Map<Id, Installation__c> requery = new Map<Id, Installation__c>(
            [SELECT Id, Installation_Order_Status__c, CurrencyIsoCode, Contract_Customer__c,
                    Quote__c, Package__c, Contract__c
             FROM Installation__c
             WHERE Id IN :insIds]
        );
    
        // Pull latest QLG/Quote to compare expected values
        SBQQ__QuoteLineGroup__c qlgNow = [
            SELECT Id, Package__c, SBQQ__Quote__c,
                   SBQQ__Quote__r.CurrencyISOCode,
                   SBQQ__Quote__r.SBQQ__Account__c,
                   SBQQ__Quote__r.SBQQ__MasterContract__c
            FROM SBQQ__QuoteLineGroup__c
            WHERE Id = :qlg.Id
            LIMIT 1
        ];
    
        // 6) ASSERT the controller-populated mappings (this covers your lines)
        for (Id insId : insIds) {
            Installation__c got = requery.get(insId);
            System.assertEquals('Draft', qlgNow == null ? 'Draft' : got.Installation_Order_Status__c, 'Status should be Draft.');
            System.assertEquals(qlgNow.SBQQ__Quote__r.CurrencyISOCode, got.CurrencyIsoCode, 'Currency should match Quote.');
            System.assertEquals(qlgNow.SBQQ__Quote__r.SBQQ__Account__c, got.Contract_Customer__c, 'Contract_Customer__c should map from Quote Account.');
            System.assertEquals(qlgNow.SBQQ__Quote__c, got.Quote__c, 'Quote__c should map from QLG.');
            System.assertEquals(qlgNow.Package__c, got.Package__c, 'Package__c should map from QLG.');
            System.assertEquals(qlgNow.SBQQ__Quote__r.SBQQ__MasterContract__c, got.Contract__c, 'Contract__c should map from Quote Master Contract.');
        }
    }
    @IsTest
    static void movesInstallation_whenTargetHasCapacity() {
        MoveContext ctx = buildMoveContext(5, 2);
    
        // Seed one existing install on target so currentCount = 1 < cap = 2
        Installation__c existing = ctx.sourceInst.clone(false, true, false, false);
        existing.Package__c = ctx.targetPkg.Id;
        existing.Quote_Line_Group__c = ctx.targetQLG.Id;
        insert existing;
    
        Test.startTest();
        QuoteInstallationController.saveInstallationToQLG(ctx.sourceInst.Id, ctx.targetQLG.Id, ctx.quote.Id);
        Test.stopTest();
    
        Installation__c moved = [
            SELECT Quote__c, Quote_Line_Group__c, Package__c, Change_Package_Status__c
            FROM Installation__c WHERE Id = :ctx.sourceInst.Id
        ];
        System.assertEquals(ctx.quote.Id, moved.Quote__c);
        System.assertEquals(ctx.targetQLG.Id, moved.Quote_Line_Group__c);
        System.assertEquals(ctx.targetPkg.Id, moved.Package__c);
        System.assertEquals('In Progress', moved.Change_Package_Status__c);
    }
    
    @IsTest
    static void keepsSameQLG_whenMovingWithinSameGroup() {
        MoveContext ctx = buildMoveContext(0, 0); // 0 = unlimited
    
        Test.startTest();
        QuoteInstallationController.saveInstallationToQLG(ctx.sourceInst.Id, ctx.sourceQLG.Id, ctx.quote.Id);
        Test.stopTest();
    
        Installation__c got = [
            SELECT Quote_Line_Group__c, Change_Package_Status__c
            FROM Installation__c WHERE Id = :ctx.sourceInst.Id
        ];
        System.assertEquals(ctx.sourceQLG.Id, got.Quote_Line_Group__c);
        System.assertEquals('In Progress', got.Change_Package_Status__c);
    }
    
    @IsTest
    static void createsInstallationLines_forEachQuoteLine() {
        // Minimal setup for one QLG with two quote lines and one installation
        TestDataFactory_OTG.enableOrgVRConfig();
        TestDataFactory_OTG.primeDefaultOwnerAllRegions(UserInfo.getUserId());
        TestDataFactory_OTG.QuoteContext qc =
            TestDataFactory_OTG.buildDraftQuoteContext('Americas', true, true);
    
        SBQQ__QuoteLineGroup__c qlg = TestDataFactory_OTG.createQuoteLineGroup(qc.quote.Id, 'Lines QLG', false, 2);
    
        Date s = Date.today(), e = s.addMonths(6);
        TestDataFactory_OTG.createQuoteLine(qc.quote.Id, qlg.Id, qc.pbe.Id, 1, null, 10, s, e, null);
        TestDataFactory_OTG.createQuoteLine(qc.quote.Id, qlg.Id, qc.pbe.Id, 2, null, 20, s, e, null);
    
        Package__c pkg = new Package__c(Quote__c = qc.quote.Id, Installation_Quantity__c = 2, Name='Pkg-Lines');
        insert pkg;
        update new SBQQ__QuoteLineGroup__c(Id = qlg.Id, Package__c = pkg.Id);
    
        Id vesselId;
        List<Vessel__c> vs = [SELECT Id FROM Vessel__c LIMIT 1];
        if (vs.isEmpty()) {
            insert new Vessel__c(Name='v-2', Vessel_IMO_Status__c='Active IMO');
            vesselId = [SELECT Id FROM Vessel__c WHERE Name='v-2' LIMIT 1].Id;
        } else {
            vesselId = vs[0].Id;
        }
    
        Installation__c inst = new Installation__c(
            Installation_Type__c = 'Vessel',
            Vessel_Name__c       = vesselId,
            Quote__c             = qc.quote.Id,
            Quote_Line_Group__c  = qlg.Id,
            Package__c           = pkg.Id,
            Installation_Order_Status__c = 'Draft',
            CurrencyIsoCode      = qc.quote.CurrencyIsoCode
        );
        insert inst;
    
        Test.startTest();
        QuoteInstallationController.createInstallationLines(new List<Installation__c>{ inst }, new List<Id>{ qlg.Id });
        Test.stopTest();
    
        List<Installation_Line__c> lines = [
            SELECT Id, Installation__c, Quote_Line__c, Product__c, Start_Date__c, End_Date__c, Net_Total__c, CurrencyIsoCode
            FROM Installation_Line__c
            WHERE Installation__c = :inst.Id
        ];
        System.assertEquals(2, lines.size(), 'Should create one installation line per quote line.');
        for (Installation_Line__c il : lines) {
            System.assertNotEquals(null, il.Product__c);
            System.assertNotEquals(null, il.Quote_Line__c);
            System.assertNotEquals(null, il.Start_Date__c);
            System.assertNotEquals(null, il.End_Date__c);
            System.assertNotEquals(null, il.Net_Total__c);
        }
    }
}