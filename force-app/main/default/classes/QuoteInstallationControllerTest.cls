@IsTest
private class QuoteInstallationControllerTest {

    private static Id quoteId;
    private static Id primaryQLGId;
    private static Id secondaryQLGId;
    private static Id primaryPackageId;
    private static Id secondaryPackageId;
    private static Id primaryInstallationId;
    private static Id secondaryInstallationId;
    private static Id invoiceAccountId;
    private static String invoiceAccountExternalId;
    private static Id vesselId;
    private static Id deliveryContactId;
    private static Id b2bAccountId;
    private static Id primaryQuoteLineId;
    private static Id secondaryQuoteLineId;

    @TestSetup
    static void setupData() {
        Profile salesProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'OTG Sales User'
            LIMIT 1
        ];

        User salesUser = (User)TestDataFactory.createSObject(
            'User',
            new Map<String, Object>{
                'ProfileId' => salesProfile.Id,
                'Username'  => 'quote.install.' + System.currentTimeMillis() + '@example.com'
            }
        );

        TestDataFactory.createSObject(
            'Default_Account_Owner_Settings__c',
            new Map<String, Object>{
                'EMEA_Default_Owner_ID__c' => salesUser.Id
            }
        );

        Country_Mapping__c country = new Country_Mapping__c(
            Name = 'QI Country',
            Sales_Region__c = 'Americas'
        );
        insert country;

        Account b2bAccount = new Account(
            Name = 'QI B2B Account',
            Account_Status__c = 'Unverified',
            AccountSource = 'Cross Department Referral',
            Address1__c = '123 Test Street',
            Town_City__c = 'Austin',
            Country__c = country.Id,
            Account_Segmentation__c = 'Unknown',
            Customer_Type__c = 'Charity',
            OwnerId = salesUser.Id
        );
        insert b2bAccount;
        b2bAccountId = b2bAccount.Id;

        Account invoiceAccount = new Account(
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName()
                .get('Invoice Account').getRecordTypeId(),
            Name = 'QI Invoice Account',
            Company__c = 'QI Co',
            CurrencyIsoCode = 'USD',
            Invoice_Emails__c = 'invoice@example.com',
            Town_City__c = 'Austin',
            B2B_Account__c = b2bAccount.Id,
            Country__c = country.Id
        );
        insert invoiceAccount;
        invoiceAccountId = invoiceAccount.Id;
        invoiceAccountExternalId = invoiceAccount.Account_ID__c;
        if (String.isBlank(invoiceAccountExternalId)) {
            invoiceAccountExternalId = 'NO_MATCH';
        }

        Opportunity opp = new Opportunity(
            Name = 'QI Opportunity',
            LeadSource = 'Cross Department Referral',
            Business_Unit__c = 'Technical Ship Management',
            Sales_Type__c = 'Subscription',
            AccountId = b2bAccount.Id,
            CloseDate = Date.today().addDays(30),
            StageName = 'Prospecting & Qualifying',
            Amount = 1000
        );
        insert opp;

        Product2 product = (Product2)TestDataFactory.createSObject(
            'Product2',
            new Map<String, Object>{
                'ProductCode' => 'QI-PROD',
                'IsActive'    => true
            }
        );
        PricebookEntry pbe = (PricebookEntry)TestDataFactory.createSObject(
            'PricebookEntry',
            new Map<String, Object>{
                'Product2Id'   => product.Id,
                'Pricebook2Id' => Test.getStandardPriceBookId(),
                'UnitPrice'    => 100,
                'IsActive'     => true
            }
        );

        Contact contact = (Contact)TestDataFactory.createSObject(
            'Contact',
            new Map<String, Object>{
                'AccountId'   => b2bAccount.Id,
                'LastName'    => 'QI Contact',
                'Job_Role__c' => 'Crew / Seafarer'
            }
        );
        deliveryContactId = contact.Id;

        SBQQ__Quote__c quote = (SBQQ__Quote__c)TestDataFactory.createSObject(
            'SBQQ__Quote__c',
            new Map<String, Object>{
                'SBQQ__Account__c'      => b2bAccount.Id,
                'SBQQ__Opportunity2__c' => opp.Id,
                'SBQQ__StartDate__c'    => Date.today(),
                'SBQQ__SubscriptionTerm__c' => 12,
                'SBQQ__Primary__c'      => true,
                'SBQQ__PricebookId__c'  => Test.getStandardPriceBookId()
            }
        );
        quoteId = quote.Id;

        Package__c primaryPackage = (Package__c)TestDataFactory.createSObject(
            'Package__c',
            new Map<String, Object>{
                'Quote__c'                => quote.Id,
                'Installation_Quantity__c'=> 3,
                'Name'                    => 'Primary Package'
            }
        );
        primaryPackageId = primaryPackage.Id;

        Package__c secondaryPackage = (Package__c)TestDataFactory.createSObject(
            'Package__c',
            new Map<String, Object>{
                'Quote__c'                => quote.Id,
                'Installation_Quantity__c'=> 2,
                'Name'                    => 'Secondary Package'
            }
        );
        secondaryPackageId = secondaryPackage.Id;

        SBQQ__QuoteLineGroup__c primaryQLG = (SBQQ__QuoteLineGroup__c)TestDataFactory.createSObject(
            'SBQQ__QuoteLineGroup__c',
            new Map<String, Object>{
                'SBQQ__Quote__c'          => quote.Id,
                'Package__c'              => primaryPackage.Id,
                'Installation_Quantity__c'=> 3,
                'User_Quantity__c'        => 3,
                'Name'                    => 'Primary QLG'
            }
        );
        primaryQLGId = primaryQLG.Id;

        SBQQ__QuoteLineGroup__c secondaryQLG = (SBQQ__QuoteLineGroup__c)TestDataFactory.createSObject(
            'SBQQ__QuoteLineGroup__c',
            new Map<String, Object>{
                'SBQQ__Quote__c'          => quote.Id,
                'Package__c'              => secondaryPackage.Id,
                'Installation_Quantity__c'=> 2,
                'User_Quantity__c'        => 2,
                'Name'                    => 'Secondary QLG'
            }
        );
        secondaryQLGId = secondaryQLG.Id;

        SBQQ__QuoteLine__c primaryLine = (SBQQ__QuoteLine__c)TestDataFactory.createSObject(
            'SBQQ__QuoteLine__c',
            new Map<String, Object>{
                'SBQQ__Quote__c'           => quote.Id,
                'SBQQ__Group__c'           => primaryQLG.Id,
                'SBQQ__Product__c'         => product.Id,
                'SBQQ__PricebookEntryId__c'=> pbe.Id,
                'SBQQ__Quantity__c'        => 1,
                'SBQQ__NetPrice__c'        => 100
            }
        );
        primaryQuoteLineId = primaryLine.Id;

        SBQQ__QuoteLine__c secondaryLine = (SBQQ__QuoteLine__c)TestDataFactory.createSObject(
            'SBQQ__QuoteLine__c',
            new Map<String, Object>{
                'SBQQ__Quote__c'           => quote.Id,
                'SBQQ__Group__c'           => secondaryQLG.Id,
                'SBQQ__Product__c'         => product.Id,
                'SBQQ__PricebookEntryId__c'=> pbe.Id,
                'SBQQ__Quantity__c'        => 1,
                'SBQQ__NetPrice__c'        => 120
            }
        );
        secondaryQuoteLineId = secondaryLine.Id;

        Vessel__c vessel = (Vessel__c)TestDataFactory.createSObject(
            'Vessel__c',
            new Map<String, Object>{
                'Name'             => 'QI Vessel',
                'Vessel_IMO__c'    => 'IMO001',
                'Vessel_IMO_Status__c' => 'Active IMO'
            }
        );
        vesselId = vessel.Id;

        Installation__c primaryInstall = new Installation__c(
            Contract_Customer__c = b2bAccount.Id,
            Package__c = primaryPackage.Id,
            Quote__c = quote.Id,
            Quote_Line_Group__c = primaryQLG.Id,
            Installation_Order_Status__c = 'Draft',
            Installation_Type__c = 'Vessel',
            Vessel_Name__c = vessel.Id,
            Invoice_Account__c = invoiceAccount.Id
        );
        insert primaryInstall;
        primaryInstallationId = primaryInstall.Id;

        insert new Installation__c(
            Contract_Customer__c = b2bAccount.Id,
            Package__c = primaryPackage.Id,
            Quote__c = quote.Id,
            Quote_Line_Group__c = primaryQLG.Id,
            Installation_Order_Status__c = 'Future Terminated',
            Installation_Type__c = 'Vessel',
            Vessel_Name__c = vessel.Id
        );

        Installation__c secondaryInstall = new Installation__c(
            Contract_Customer__c = b2bAccount.Id,
            Package__c = secondaryPackage.Id,
            Quote__c = quote.Id,
            Quote_Line_Group__c = secondaryQLG.Id,
            Installation_Order_Status__c = 'Draft',
            Installation_Type__c = 'Vessel',
            Vessel_Name__c = vessel.Id
        );
        insert secondaryInstall;
        secondaryInstallationId = secondaryInstall.Id;
    }

    @IsTest
    static void testFetchQuoteLineGroupsFiltersFutureTerminated() {
        String payload;
        try {
            Test.startTest();
            payload = QuoteInstallationController.fetchQuoteLineGroups(quoteId);
            Test.stopTest();
        } catch (Exception ex) {
            System.assert(false, 'fetchQuoteLineGroups threw: ' + ex.getMessage());
            return;
        }

        System.assertNotEquals(null, payload, 'Expected JSON payload.');
        List<Object> wrappers = (List<Object>)JSON.deserializeUntyped(payload);
        System.assert(!wrappers.isEmpty(), 'At least one wrapper expected.');

        Boolean futureTerminatedFound = false;
        for (Object obj : wrappers) {
            Map<String, Object> wrapper = (Map<String, Object>)obj;
            Map<String, Object> pack = (Map<String, Object>)wrapper.get('pack');
            if (pack == null || !pack.containsKey('Installations__r')) {
                continue;
            }
            Map<String, Object> rel = (Map<String, Object>)pack.get('Installations__r');
            List<Object> installs = (List<Object>)rel.get('records');
            for (Object recObj : installs) {
                Map<String, Object> rec = (Map<String, Object>)recObj;
                String status = (String)rec.get('Installation_Order_Status__c');
                System.assertNotEquals('Future Terminated', status,
                    'Future terminated installation should be excluded.');
                if ('Future Terminated'.equals(status)) {
                    futureTerminatedFound = true;
                }
            }
        }
        System.assertEquals(false, futureTerminatedFound, 'Future terminated rows must not appear.');
    }

    @IsTest
    static void testFetchQuoteLineGroupProductsReturnsProducts() {
        String products;
        try {
            Test.startTest();
            products = QuoteInstallationController.fetchQuoteLineGroupProducts(primaryQLGId);
            Test.stopTest();
        } catch (Exception ex) {
            System.assert(false, 'fetchQuoteLineGroupProducts threw: ' + ex.getMessage());
            return;
        }
        System.assertNotEquals(null, products, 'Products CSV should not be null.');
        System.assert(products.contains('QI-PROD'), 'Products CSV should include the product code.');
    }

    @IsTest
    static void testCreateRecordsInsertsInstallations() {
        List<Installation__c> created;
        try {
            Test.startTest();
            created = QuoteInstallationController.createRecords(
                quoteId,
                primaryQLGId,
                1,
                deliveryContactId,
                invoiceAccountId,
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
        System.assertEquals(quoteId, inserted.Quote__c);
        System.assertEquals(primaryQLGId, inserted.Quote_Line_Group__c);
        System.assertEquals(primaryPackageId, inserted.Package__c);
    }

    @IsTest
    static void testCreateInstallationsProcessesCsv() {
        String csv = 'VesselIMO,InvoiceAccount\n' +
            'IMO001,' + (invoiceAccountExternalId != null ? invoiceAccountExternalId : '') + '\n';
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
                quoteId,
                primaryQLGId,
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
    static void testSaveInstallationPopulatesDerivedFields() {
        List<sObject> toInsert = new List<sObject>{
            new Installation__c(
                Installation_Type__c = 'Vessel',
                Vessel_Name__c = vesselId,
                Quote_Line_Group__c = primaryQLGId
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
        System.assertEquals(quoteId, inserted.Quote__c);
        System.assertEquals(primaryPackageId, inserted.Package__c);
        System.assertNotEquals(null, inserted.Contract_Customer__c);
    }

    @IsTest
    static void testSaveInstallationToQLGMovesInstallation() {
        try {
            Test.startTest();
            QuoteInstallationController.saveInstallationToQLG(
                primaryInstallationId,
                secondaryQLGId,
                quoteId
            );
            Test.stopTest();
        } catch (Exception ex) {
            System.assert(false, 'saveInstallationToQLG threw: ' + ex.getMessage());
            return;
        }

        Installation__c moved = [
            SELECT Quote_Line_Group__c, Package__c, Change_Package_Status__c
            FROM Installation__c
            WHERE Id = :primaryInstallationId
        ];
        System.assertEquals(secondaryQLGId, moved.Quote_Line_Group__c);
        System.assertEquals(secondaryPackageId, moved.Package__c);
        System.assertEquals('In Progress', moved.Change_Package_Status__c);
    }

    @IsTest
    static void testSaveInstallationToQLGRespectsCapacity() {
        update new SBQQ__QuoteLineGroup__c(
            Id = secondaryQLGId,
            Installation_Quantity__c = 1
        );

        Installation__c extra = new Installation__c(
            Contract_Customer__c = b2bAccountId,
            Quote__c = quoteId,
            Quote_Line_Group__c = primaryQLGId,
            Package__c = primaryPackageId,
            Installation_Order_Status__c = 'Draft',
            Installation_Type__c = 'Vessel',
            Vessel_Name__c = vesselId
        );
        insert extra;

        Boolean threwCapacityException = false;
        try {
            QuoteInstallationController.saveInstallationToQLG(
                extra.Id,
                secondaryQLGId,
                quoteId
            );
        } catch (AuraHandledException ex) {
            threwCapacityException = ex.getMessage().contains('at capacity');
        }
        System.assertEquals(true, threwCapacityException, 'Capacity error should be raised.');
    }

    @IsTest
    static void testCreateInstallationLinesGeneratesEntries() {
        Installation__c inst = new Installation__c(
            Contract_Customer__c = b2bAccountId,
            Quote__c = quoteId,
            Quote_Line_Group__c = primaryQLGId,
            Package__c = primaryPackageId,
            Installation_Order_Status__c = 'Draft',
            Installation_Type__c = 'Vessel',
            Vessel_Name__c = vesselId
        );
        insert inst;

        try {
            Test.startTest();
            QuoteInstallationController.createInstallationLines(
                new List<Installation__c>{ inst },
                new List<Id>{ primaryQLGId }
            );
            Test.stopTest();
        } catch (Exception ex) {
            System.assert(false, 'createInstallationLines threw: ' + ex.getMessage());
            return;
        }

        List<Installation_Line__c> lines = [
            SELECT Installation__c, Quote_Line__c, Product__c
            FROM Installation_Line__c
            WHERE Installation__c = :inst.Id
        ];
        System.assertEquals(1, lines.size(), 'One installation line expected.');
        System.assertNotEquals(null, lines[0].Quote_Line__c);
        System.assertNotEquals(null, lines[0].Product__c);
    }
}