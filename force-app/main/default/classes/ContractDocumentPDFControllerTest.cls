@IsTest
private class ContractDocumentPDFControllerTest {

    @TestSetup
    static void setupData() {
        // Use running user so flows assigning owner have a valid Id
        User running = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        // Default owner settings used by your Account insert flow
        insert new Default_Account_Owner_Settings__c(
            Name = 'Test Defaults',
            EMEA_Default_Owner_ID__c = running.Id,
            Americas_Default_Owner_ID__c = running.Id,
            APAC_Default_Owner_ID__c = running.Id
        );

        // Country mapping aligned to a region with default owner
        Country_Mapping__c cm = new Country_Mapping__c(
            Name = 'Test',
            Sales_Region__c = 'EMEA'
        );
        insert cm;

        // Get the required Account Record Type for Invoice Accounts
        Id invoiceRtId;
        Map<String, Schema.RecordTypeInfo> acctRTs = Schema.SObjectType.Account.getRecordTypeInfosByName();
        if (acctRTs != null) {
            if (acctRTs.containsKey('Invoice Account')) {
                invoiceRtId = acctRTs.get('Invoice Account').getRecordTypeId();
            } else if (acctRTs.containsKey('Replica Invoice Account')) {
                invoiceRtId = acctRTs.get('Replica Invoice Account').getRecordTypeId();
            }
        }
        
        // --- Contract Customer Account ---
        Account acc = new Account(
            Name = 'Test Customer',
            Account_Status__c = 'Unverified',
            AccountSource = 'Cross Department Referral',
            Address1__c = 'Line1',
            Town_City__c = 'London',
            Country__c = cm.Id,
            Account_Segmentation__c = 'Unknown',
            Customer_Type__c = 'Charity'
        );
        insert acc;
        
        // --- Invoice Account (must have the correct Record Type) ---
        Account invAcc = new Account(
            RecordTypeId = invoiceRtId,               // REQUIRED by the lookup filter
            Name = 'Invoice Account',
            Company__c = 'TestCo',
            CurrencyIsoCode = 'USD',
            Invoice_Emails__c = 'a@x.com;b@y.com',
            Town_City__c = 'Town',
            B2B_Account__c = acc.Id
        );
        insert invAcc;

        // Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting & Qualifying',
            CloseDate = Date.today().addDays(30),
            Amount = 1000,
            Business_Unit__c = 'Technical Ship Management'
        );
        insert opp;

        // Product + PBE (minimal; no heavy CPQ calc)
        Id stdPbId = Test.getStandardPriceBookId();
        Product2 p = new Product2(Name = 'Prod A', IsActive = true);
        insert p;
        PricebookEntry pbe = new PricebookEntry(
            Product2Id = p.Id,
            Pricebook2Id = stdPbId,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        // --- LIGHT QUOTE (no lines): used by the "lite" test method ---
        SBQQ__Quote__c qtLite = new SBQQ__Quote__c(
            SBQQ__Account__c = acc.Id,
            SBQQ__Opportunity2__c = opp.Id,
            SBQQ__SubscriptionTerm__c = 12,
            SBQQ__BillingFrequency__c = 'Annual',
            SBQQ__PricebookId__c = stdPbId,
            SBQQ__Primary__c = true
            // Do NOT set Status to 'Approved' to avoid heavy CPQ trigger/workflow fan-out
        );
        insert qtLite;

        // --- FULL QUOTE: 1 group (with Package), 1 line, 1 installation on that package ---
        SBQQ__Quote__c qtFull = new SBQQ__Quote__c(
            SBQQ__Account__c = acc.Id,
            SBQQ__Opportunity2__c = opp.Id,
            SBQQ__SubscriptionTerm__c = 12,
            SBQQ__BillingFrequency__c = 'Annual',
            SBQQ__PricebookId__c = stdPbId,
            SBQQ__Primary__c = true
        );
        insert qtFull;

        // Create a Package used by the group
        Package__c pack = new Package__c(
            Name = 'Pack-1',
            Quote__c = qtFull.Id,
            Installation_Quantity__c = 2,// the controller sums this
            InstallationCost__c = 250,   // controller also reads this field name
            Products__c = 'Product A'
        );
        insert pack;

        // Group tied to the Package
        SBQQ__QuoteLineGroup__c grp = new SBQQ__QuoteLineGroup__c(
            SBQQ__Quote__c = qtFull.Id,
            Package__c = pack.Id,
            Installation_Quantity__c = 2,
            Current_Price__c = 90
        );
        insert grp;

        // One Quote Line under that group
        SBQQ__QuoteLine__c ql = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = qtFull.Id,
            SBQQ__Group__c = grp.Id,
            SBQQ__Product__c = p.Id,
            SBQQ__PricebookEntryId__c = pbe.Id,
            SBQQ__Quantity__c = 3,
            Remove_Product_from_Package__c = false
        );
        insert ql;

        // --- Installation must reference the same Contract Customer and this Invoice Account ---
        Installation__c inst = new Installation__c(
            Package__c = pack.Id,
            Contract_Customer__c = acc.Id,            // Contract Customer ID
            Invoice_Account__c = invAcc.Id,           // Invoice Account with correct RT + matching B2B Account’s Account_ID__c
            Installation_Order_Status__c = 'Active',
            CurrencyIsoCode = 'USD',
            Installation_Name__c = 'INST-1'
        );
        insert inst;
    }

    // ------------------ TESTS ------------------

    // 1) Light path: no quote lines (covers top part: quote fetch, date/formatting, content version lookup)
    @IsTest
    static void test_Controller_Lite_NoLines() {
        SBQQ__Quote__c qtLite = [SELECT Id FROM SBQQ__Quote__c WHERE SBQQ__SubscriptionTerm__c = 12 AND SBQQ__Primary__c = true LIMIT 1];

        PageReference pr = Page.ContractDocumentPDF; // adjust if your page API name differs
        Test.setCurrentPage(pr);
        ApexPages.currentPage().getParameters().put('id', qtLite.Id);

        Test.startTest();
        ApexPages.StandardController sc = new ApexPages.StandardController(qtLite);
        ContractDocumentPDFController ctrl = new ContractDocumentPDFController(sc);
        Test.stopTest();

        System.assertNotEquals(null, ctrl.qt, 'Quote should be loaded');
        System.assertNotEquals(null, ctrl.formattedDate, 'Formatted date should be computed');
        // With no lines, packWrapList should be empty, but code path is executed
        System.assertNotEquals(null, ctrl.packWrapList, 'Pack wrapper list initialised');
    }

    // 2) Full path: one line in a group with a Package + one Installation
    //    (covers product aggregation, pack map, installations loop, invoice wrappers, total install cost)
    @IsTest
    static void test_Controller_Full_WithLinesAndInstall() {
        // Select the quote that has a group and package (qtFull)
        SBQQ__Quote__c qtFull = [
            SELECT Id FROM SBQQ__Quote__c
            WHERE Id IN (SELECT Quote__c FROM Package__c)
            LIMIT 1
        ];

        PageReference pr = Page.ContractDocumentPDF;
        Test.setCurrentPage(pr);
        ApexPages.currentPage().getParameters().put('id', qtFull.Id);

        Test.startTest();
        ApexPages.StandardController sc = new ApexPages.StandardController(qtFull);
        ContractDocumentPDFController ctrl = new ContractDocumentPDFController(sc);
        Test.stopTest();

        // Validate key outputs driven by the controller logic
        System.assert(ctrl.packWrapList != null && ctrl.packWrapList.size() > 0, 'Package wrappers should be built');
        System.assert(ctrl.instList != null && ctrl.instList.size() == 1, 'One installation should be fetched');
        System.assertEquals(true, ctrl.hasInv, 'Invoice details should be detected');
        System.assert(ctrl.invWrapList != null && ctrl.invWrapList.size() == 1, 'Invoice wrapper should be created');

        // Ensure email separator replacement happened (a@x.com;b@y.com -> with newline)
        Boolean foundNewline = ctrl.invWrapList[0].invEmail != null && ctrl.invWrapList[0].invEmail.contains('\n');
        System.assertEquals(true, foundNewline, 'Invoice emails should be converted to newline-separated');
    }

    // 3) Utility method coverage
    @IsTest
    static void test_formatDateWithOrdinal() {
        System.assertEquals('1st January 2024',
            ContractDocumentPDFController.formatDateWithOrdinal(Date.newInstance(2024, 1, 1)));
        System.assertEquals('2nd January 2024',
            ContractDocumentPDFController.formatDateWithOrdinal(Date.newInstance(2024, 1, 2)));
        System.assertEquals('3rd January 2024',
            ContractDocumentPDFController.formatDateWithOrdinal(Date.newInstance(2024, 1, 3)));
        System.assertEquals('11th January 2024',
            ContractDocumentPDFController.formatDateWithOrdinal(Date.newInstance(2024, 1, 11)));
        System.assertEquals('13th January 2024',
            ContractDocumentPDFController.formatDateWithOrdinal(Date.newInstance(2024, 1, 13)));
        System.assertEquals('31st December 2024',
            ContractDocumentPDFController.formatDateWithOrdinal(Date.newInstance(2024, 12, 31)));
    }
}