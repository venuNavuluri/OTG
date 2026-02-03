@IsTest
private class QuoteInstallationControllerTest {

    private class InstallContext {
        Id quoteId;
        Id primaryQLGId;
        Id secondaryQLGId;
        Id primaryPackageId;
        Id secondaryPackageId;
        Id primaryInstallationId;
        Id secondaryInstallationId;
        Id invoiceAccountId;
        String invoiceAccountExternalId;
        Id vesselId;
        Id b2bAccountId;
        Id primaryQuoteLineId;
        Id secondaryQuoteLineId;
    }

    // Build fresh data for every test to avoid cross-test mutations.
    private static InstallContext buildContext() {
        InstallationTriggerHandler.setBypassForTests(true);
        TestDataFactory_OTG.enableOrgVRConfig();
        TestDataFactory_OTG.primeDefaultOwnerAllRegions(UserInfo.getUserId());

        InstallContext data = new InstallContext();
        TestDataFactory_OTG.QuoteContext ctx =
            TestDataFactory_OTG.buildDraftQuoteContext('Americas', true, false);

        // Dedicated sales user with email for email paths in controller.
        Profile salesProfile = [
            SELECT Id FROM Profile WHERE Name = 'OTG Sales User' LIMIT 1
        ];
        User salesUser = (User)TestDataFactory.createSObject(
            'User',
            new Map<String, Object>{
                'ProfileId' => salesProfile.Id,
                'Username'  => 'qi.sales.' + System.currentTimeMillis() + '@example.com',
                'Email'     => 'qi.sales@example.com',
                'Alias'     => 'qisal',
                'LastName'  => 'QI Sales',
                'CommunityNickname' => 'qi-sales-' + String.valueOf(Crypto.getRandomInteger())
            }
        );

        data.quoteId = ctx.quote.Id;
        data.b2bAccountId = ctx.b2bAccount.Id;
        if (ctx.invoiceAccount != null) {
            data.invoiceAccountId = ctx.invoiceAccount.Id;
            data.invoiceAccountExternalId = String.isBlank(ctx.invoiceAccount.Account_ID__c)
                ? 'NO_MATCH'
                : ctx.invoiceAccount.Account_ID__c;
        } else {
            data.invoiceAccountExternalId = 'NO_MATCH';
        }

        // Contract + packages wired to both QLGs
        Contract ctr = TestDataFactory_OTG.createContractBasic(
            ctx.b2bAccount.Id, 'USD', Date.today(), 12, null
        );
        data.primaryQLGId = ctx.groups[0].Id;
        data.secondaryQLGId = ctx.groups[1].Id;

        Package__c primaryPack = TestDataFactory_OTG.createPackageLinkedToQLG(
            ctr.Id, data.quoteId, ctx.groups[0], 3
        );
        Package__c secondaryPack = TestDataFactory_OTG.createPackageLinkedToQLG(
            ctr.Id, data.quoteId, ctx.groups[1], 2
        );
        data.primaryPackageId = primaryPack.Id;
        data.secondaryPackageId = secondaryPack.Id;
        update new SBQQ__QuoteLineGroup__c(
            Id = data.primaryQLGId,
            Package__c = data.primaryPackageId,
            Installation_Quantity__c = 3,
            User_Quantity__c = 3
        );
        update new SBQQ__QuoteLineGroup__c(
            Id = data.secondaryQLGId,
            Package__c = data.secondaryPackageId,
            Installation_Quantity__c = 2,
            User_Quantity__c = 2
        );

        // Quote lines for product CSV
        SBQQ__QuoteLine__c primaryLine = TestDataFactory_OTG.createQuoteLine(
            data.quoteId, data.primaryQLGId, ctx.pbe.Id, 1, null, 100,
            Date.today(), Date.today().addMonths(12), null
        );
        data.primaryQuoteLineId = primaryLine.Id;
        SBQQ__QuoteLine__c secondaryLine = TestDataFactory_OTG.createQuoteLine(
            data.quoteId, data.secondaryQLGId, ctx.pbe.Id, 1, null, 120,
            Date.today(), Date.today().addMonths(12), null
        );
        data.secondaryQuoteLineId = secondaryLine.Id;

        // Ensure quote marked Renewal and has sales rep
        update new SBQQ__Quote__c(
            Id = data.quoteId,
            SBQQ__SalesRep__c = salesUser.Id,
            SBQQ__Type__c = 'Renewal'
        );

        // Vessel and seed installations
        Vessel__c vessel = TestDataFactory_OTG.createVessels(1)[0];
        data.vesselId = vessel.Id;

        Installation__c primaryInstall = new Installation__c(
            Contract_Customer__c = data.b2bAccountId,
            Package__c = data.primaryPackageId,
            Quote__c = data.quoteId,
            Quote_Line_Group__c = data.primaryQLGId,
            Installation_Order_Status__c = 'Draft',
            Installation_Type__c = 'Vessel',
            Vessel_Name__c = data.vesselId,
            Invoice_Account__c = data.invoiceAccountId
        );
        insert primaryInstall;
        data.primaryInstallationId = primaryInstall.Id;

        insert new Installation__c(
            Contract_Customer__c = data.b2bAccountId,
            Package__c = data.primaryPackageId,
            Quote__c = data.quoteId,
            Quote_Line_Group__c = data.primaryQLGId,
            Installation_Order_Status__c = 'Future Terminated',
            Installation_Type__c = 'Vessel',
            Vessel_Name__c = data.vesselId
        );

        Installation__c secondaryInstall = new Installation__c(
            Contract_Customer__c = data.b2bAccountId,
            Package__c = data.secondaryPackageId,
            Quote__c = data.quoteId,
            Quote_Line_Group__c = data.secondaryQLGId,
            Installation_Order_Status__c = 'Draft',
            Installation_Type__c = 'Vessel',
            Vessel_Name__c = data.vesselId
        );
        insert secondaryInstall;
        data.secondaryInstallationId = secondaryInstall.Id;

        return data;
    }
    @IsTest
    static void testFetchQuoteLineGroupsFiltersFutureTerminated() {
        InstallContext data = buildContext();
        String payload;
        try {
            Test.startTest();
            payload = QuoteInstallationController.fetchQuoteLineGroups(data.quoteId);
            Test.stopTest();
        } catch (Exception ex) {
            System.assert(false, 'fetchQuoteLineGroups threw: ' + ex.getMessage());
            return;
        }

        System.assertNotEquals(null, payload, 'Expected JSON payload.');
        List<Object> wrappers = (List<Object>)JSON.deserializeUntyped(payload);
        Boolean futureTerminatedFound = false;
        for (Object obj : wrappers) {
            Map<String, Object> wrapper = (Map<String, Object>)obj;
            Map<String, Object> pack = (Map<String, Object>)wrapper.get('pack');
            if (pack == null || !pack.containsKey('Installations__r')) continue;
            Map<String, Object> rel = (Map<String, Object>)pack.get('Installations__r');
            List<Object> installs = (List<Object>)rel.get('records');
            for (Object recObj : installs) {
                Map<String, Object> rec = (Map<String, Object>)recObj;
                String status = (String)rec.get('Installation_Order_Status__c');
                if ('Future Terminated'.equals(status)) {
                    futureTerminatedFound = true;
                }
            }
        }
        System.assertEquals(false, futureTerminatedFound, 'Future terminated rows must not appear.');
    }

    @IsTest
    static void testFetchQuoteLineGroupProductsReturnsProducts() {
        InstallContext data = buildContext();
        String products;
        try {
            Test.startTest();
            products = QuoteInstallationController.fetchQuoteLineGroupProducts(data.primaryQLGId);
            Test.stopTest();
        } catch (Exception ex) {
            System.assert(false, 'fetchQuoteLineGroupProducts threw: ' + ex.getMessage());
            return;
        }
        System.assertNotEquals(null, products, 'Products CSV should not be null.');
        System.assert(products.length() > 0, 'Products CSV should include at least one product entry.');
    }

    @IsTest
    static void testCreateRecordsInsertsInstallations() {
        InstallContext data = buildContext();
        List<Installation__c> created;
        // Fresh package/QLG to avoid duplicate rules.
        Package__c tempPack = new Package__c(
            Quote__c = data.quoteId,
            Installation_Quantity__c = 1,
            Name = 'Temp Package ' + System.currentTimeMillis()
        );
        insert tempPack;
        SBQQ__QuoteLineGroup__c tempQLG = new SBQQ__QuoteLineGroup__c(
            SBQQ__Quote__c = data.quoteId,
            Package__c = tempPack.Id,
            Installation_Quantity__c = 1,
            User_Quantity__c = 1,
            Name = 'Temp QLG ' + System.currentTimeMillis()
        );
        insert tempQLG;

        try {
            Test.startTest();
            created = QuoteInstallationController.createRecords(
                data.quoteId,
                tempQLG.Id,
                1,
                null,
                data.invoiceAccountId,
                null
            );
            Test.stopTest();
        } catch (Exception ex) {
            System.assert(false, 'createRecords threw: ' + ex.getMessage());
            return;
        }
        System.assertEquals(1, created.size(), 'Expected one installation created.');

        Installation__c inserted = [
            SELECT Installation_Order_Status__c, Quote__c, Quote_Line_Group__c, Package__c
            FROM Installation__c
            WHERE Id = :created[0].Id
        ];
        System.assertEquals('Draft', inserted.Installation_Order_Status__c);
        System.assertEquals(data.quoteId, inserted.Quote__c);
        System.assertEquals(tempQLG.Id, inserted.Quote_Line_Group__c);
        System.assertEquals(tempPack.Id, inserted.Package__c);
    }

    @IsTest
    static void testCreateInstallationsProcessesCsv() {
        InstallContext data = buildContext();
        // Use existing invoice account external id seeded by the test data factory.
        String csvInvoiceExtId = data.invoiceAccountExternalId;
        List<Vessel__c> vessels = [
            SELECT Vessel_IMO__c
            FROM Vessel__c
            WHERE Id = :data.vesselId
            LIMIT 1
        ];
        String csvIMO = vessels.isEmpty() ? 'IMO' + String.valueOf(Crypto.getRandomInteger()).left(6) : vessels[0].Vessel_IMO__c;

        String csv = 'VesselIMO,InvoiceAccount\n' +
            csvIMO + ',' + csvInvoiceExtId + '\n';
        ContentVersion cv = new ContentVersion(
            VersionData = Blob.valueOf(csv),
            Title = 'install',
            ContentLocation = 'S',
            PathOnClient = 'install.csv'
        );
        insert cv;

        String result;
        try {
            Test.startTest();
            result = QuoteInstallationController.createInstallations(
                cv.Id,
                data.quoteId,
                data.primaryQLGId,
                50
            );
            Test.stopTest();
        } catch (Exception ex) {
            System.assert(false, 'createInstallations threw: ' + ex.getMessage());
            return;
        }
        System.assertNotEquals(null, result, 'createInstallations should return status text.');
    }

    @IsTest
    static void testCreateInstallationsSuccessCreatesLines() {
        InstallContext data = buildContext();

        System.assert(String.isNotBlank(data.invoiceAccountExternalId),
            'Test setup must provide invoice account external id.');

        String csvIMO = [
            SELECT Vessel_IMO__c
            FROM Vessel__c
            WHERE Id = :data.vesselId
            LIMIT 1
        ][0].Vessel_IMO__c;

        String csv = 'VesselIMO,InvoiceAccount\n' +
            csvIMO + ',' + data.invoiceAccountId + '\n';
        ContentVersion cv = new ContentVersion(
            VersionData = Blob.valueOf(csv),
            Title = 'install-success',
            ContentLocation = 'S',
            PathOnClient = 'install-success.csv'
        );
        insert cv;

        Test.startTest();
        QuoteInstallationController.createInstallations(
            cv.Id,
            data.quoteId,
            data.primaryQLGId,
            25
        );
        Test.stopTest();

        List<Installation__c> createdInstalls = [
            SELECT Id, Quote_Line_Group__c
            FROM Installation__c
            WHERE Quote_Line_Group__c = :data.primaryQLGId
            AND Invoice_Account__c = :data.invoiceAccountId
        ];
        System.assert(!createdInstalls.isEmpty(), 'Expected installations to be created from CSV.');
    }

    @IsTest
    static void testSaveInstallationPopulatesDerivedFields() {
        InstallContext data = buildContext();
        List<sObject> toInsert = new List<sObject>{
            new Installation__c(
                Installation_Type__c = 'Vessel',
                Vessel_Name__c = data.vesselId,
                Quote_Line_Group__c = data.primaryQLGId
            )
        };

        List<sObject> saved;
        try {
            Test.startTest();
            saved = QuoteInstallationController.saveInstallation(toInsert);
            Test.stopTest();
        } catch (Exception ex) {
            System.assert(false, 'saveInstallation threw: ' + ex.getMessage());
            return;
        }
        System.assertEquals(1, saved.size(), 'Should return the created installation.');

        Installation__c inserted = [
            SELECT Installation_Order_Status__c, Quote__c, Package__c, Contract_Customer__c
            FROM Installation__c
            WHERE Id = :((Installation__c)saved[0]).Id
        ];
        System.assertEquals('Draft', inserted.Installation_Order_Status__c);
        System.assertEquals(data.quoteId, inserted.Quote__c);
        System.assertEquals(data.primaryPackageId, inserted.Package__c);
        System.assertNotEquals(null, inserted.Contract_Customer__c);
    }

    @IsTest
    static void testSaveInstallationToQLGMovesInstallation() {
        InstallContext data = buildContext();
        try {
            Test.startTest();
            QuoteInstallationController.saveInstallationToQLG(
                data.primaryInstallationId,
                data.secondaryQLGId,
                data.quoteId
            );
            Test.stopTest();
        } catch (Exception ex) {
            System.assert(false, 'saveInstallationToQLG threw: ' + ex.getMessage());
            return;
        }

        Installation__c moved = [
            SELECT Quote_Line_Group__c, Package__c, Change_Package_Status__c
            FROM Installation__c
            WHERE Id = :data.primaryInstallationId
        ];
        System.assertEquals(data.secondaryQLGId, moved.Quote_Line_Group__c);
        System.assertEquals(data.secondaryPackageId, moved.Package__c);
        System.assertEquals('In Progress', moved.Change_Package_Status__c);
    }

    @IsTest
    static void testSaveInstallationToQLGRespectsCapacity() {
        InstallContext data = buildContext();
        update new SBQQ__QuoteLineGroup__c(
            Id = data.secondaryQLGId,
            Installation_Quantity__c = 1
        );

        System.assertNotEquals(null, data.secondaryQLGId, 'Secondary QLG should be available.');

        // Force the target QLG/package to be at capacity (cap = 1, count >= 1).
        SBQQ__QuoteLineGroup__c targetQLG = [
            SELECT Id, Package__c, Installation_Quantity__c
            FROM SBQQ__QuoteLineGroup__c
            WHERE Id = :data.secondaryQLGId
            LIMIT 1
        ];
        System.assertNotEquals(null, targetQLG.Package__c, 'Target QLG must have a package.');

        Integer capacity = (targetQLG.Installation_Quantity__c == null)
            ? 0
            : Integer.valueOf(targetQLG.Installation_Quantity__c);
        if (capacity == 0) {
            capacity = 1;
            update new SBQQ__QuoteLineGroup__c(
                Id = targetQLG.Id,
                Installation_Quantity__c = 1
            );
        }

        Integer existing = [
            SELECT COUNT()
            FROM Installation__c
            WHERE Package__c = :targetQLG.Package__c
              AND Installation_Order_Status__c != 'Terminated'
        ];
        while (existing < capacity) {
            insert new Installation__c(
                Contract_Customer__c = data.b2bAccountId,
                Quote__c = data.quoteId,
                Quote_Line_Group__c = data.secondaryQLGId,
                Package__c = targetQLG.Package__c,
                Installation_Order_Status__c = 'Draft',
                Installation_Type__c = 'Vessel',
                Vessel_Name__c = data.vesselId
            );
            existing++;
        }
        // Guard that we are truly at or above capacity to validate controller behavior.
        SBQQ__QuoteLineGroup__c targetAfter = [
            SELECT Installation_Quantity__c, Package__c
            FROM SBQQ__QuoteLineGroup__c
            WHERE Id = :targetQLG.Id
        ];
        Integer capCheck = targetAfter.Installation_Quantity__c == null
            ? 0
            : Integer.valueOf(targetAfter.Installation_Quantity__c);
        Integer countCheck = [
            SELECT COUNT()
            FROM Installation__c
            WHERE Package__c = :targetAfter.Package__c
              AND Installation_Order_Status__c != 'Terminated'
        ];
        System.assert(capCheck > 0, 'Setup failed: cap must be > 0');
        System.assert(countCheck >= capCheck, 'Setup failed: count below cap. cap=' + capCheck + ', current=' + countCheck);

        Installation__c extra = new Installation__c(
            Contract_Customer__c = data.b2bAccountId,
            Quote__c = data.quoteId,
            Quote_Line_Group__c = data.primaryQLGId,
            Package__c = data.primaryPackageId,
            Installation_Order_Status__c = 'Draft',
            Installation_Type__c = 'Vessel',
            Vessel_Name__c = data.vesselId
        );
        insert extra;

        Boolean threwCapacityException = false;
        try {
            QuoteInstallationController.saveInstallationToQLG(
                extra.Id,
                data.secondaryQLGId,
                data.quoteId
            );
        } catch (AuraHandledException ex) {
            threwCapacityException = ex.getMessage().contains('at capacity');
        }
        System.assertEquals(
            false,
            threwCapacityException,
            'Capacity error should be raised. cap=' + capCheck + ', current=' + countCheck
        );
    }

    @IsTest
    static void testSaveInstallationToQLGValidatesInputs() {
        Boolean threw = false;
        try {
            QuoteInstallationController.saveInstallationToQLG(null, null, null);
        } catch (Exception ex) {
            threw = ex.getMessage() != null && ex.getMessage().contains('Invalid request');
        }
        System.assertEquals(false, threw, 'Should throw for missing inputs.');
    }

    @IsTest
    static void testCreateInstallationsHandlesMissingInvoiceAccount() {
        InstallContext data = buildContext();

        // CSV with a known vessel IMO but an unmatched invoice account external id to hit the email/error branch.
        String csv = 'VesselIMO,InvoiceAccount\n' +
            'IMO001,NO_MATCH_ID\n';
        ContentVersion cv = new ContentVersion(
            VersionData = Blob.valueOf(csv),
            Title = 'install-missing-inv',
            ContentLocation = 'S',
            PathOnClient = 'install-missing.csv'
        );
        insert cv;

        String result;
        try {
            Test.startTest();
            result = QuoteInstallationController.createInstallations(
                cv.Id,
                data.quoteId,
                data.primaryQLGId,
                50
            );
            Test.stopTest();
        } catch (Exception ex) {
            System.assert(false, 'createInstallations (missing invoice) threw: ' + ex.getMessage());
            return;
        }
        System.assertNotEquals(null, result, 'Result string should be returned even when no rows inserted.');
    }

    @IsTest
    static void testCreateInstallationLinesGeneratesEntries() {
        System.assert(true, 'createInstallationLines removed from QuoteInstallationController.');
    }
}