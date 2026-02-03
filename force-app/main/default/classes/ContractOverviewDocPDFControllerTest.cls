@IsTest
private class ContractOverviewDocPDFControllerTest {

    @TestSetup
    static void setupData() {
        // Ensure flows using running-user ownership have a valid fallback
        User running = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        insert new Default_Account_Owner_Settings__c(
            Name = 'Test Defaults',
            EMEA_Default_Owner_ID__c = running.Id,
            Americas_Default_Owner_ID__c = running.Id,
            APAC_Default_Owner_ID__c = running.Id
        );

        Country_Mapping__c cm = new Country_Mapping__c(
            Name = 'Test Country',
            Sales_Region__c = 'EMEA'
        );
        insert cm;

        Id invoiceRtId;
        Map<String, Schema.RecordTypeInfo> acctRTs = Schema.SObjectType.Account.getRecordTypeInfosByName();
        if (acctRTs != null) {
            if (acctRTs.containsKey('Invoice Account')) {
                invoiceRtId = acctRTs.get('Invoice Account').getRecordTypeId();
            } else if (acctRTs.containsKey('Replica Invoice Account')) {
                invoiceRtId = acctRTs.get('Replica Invoice Account').getRecordTypeId();
            }
        }

        Account contractAccount = new Account(
            Name = 'Contract Customer',
            Account_Status__c = 'Unverified',
            AccountSource = 'Cross Department Referral',
            Address1__c = 'Addr 1',
            Address2__c = 'Addr 2',
            Address3__c = 'Addr 3',
            Town_City__c = 'London',
            County_State__c = 'Greater London',
            Postcode_Zipcode__c = 'A1 1AA',
            Country__c = cm.Id,
            Account_Segmentation__c = 'Unknown',
            Customer_Type__c = 'Charity'
        );
        insert contractAccount;

        Account invoiceAccount = new Account(
            RecordTypeId = invoiceRtId,
            Name = 'Invoice Account',
            Company__c = 'TestCo',
            CurrencyIsoCode = 'USD',
            Invoice_Emails__c = 'accounts@test.com;billing@test.com',
            Address1__c = 'Inv Addr 1',
            Address2__c = 'Inv Addr 2',
            Town_City__c = 'Manchester',
            County_State__c = 'Greater Manchester',
            Postcode_Zipcode__c = 'B2 2BB',
            Country__c = cm.Id,
            B2B_Account__c = contractAccount.Id
        );
        insert invoiceAccount;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = contractAccount.Id,
            StageName = 'Prospecting & Qualifying',
            CloseDate = Date.today().addDays(30),
            Amount = 1000,
            Business_Unit__c = 'Technical Ship Management'
        );
        insert opp;

        Id stdPbId = Test.getStandardPriceBookId();
        Product2 prod = new Product2(Name = 'Coverage Product', IsActive = true);
        insert prod;

        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Account__c = contractAccount.Id,
            SBQQ__Opportunity2__c = opp.Id,
            SBQQ__SubscriptionTerm__c = 12,
            SBQQ__BillingFrequency__c = 'Annual',
            SBQQ__PricebookId__c = stdPbId,
            SBQQ__Primary__c = true,
            SBQQ__PaymentTerms__c = 'Net 30'
        );
        insert quote;

        Contract contr = new Contract(
            AccountId = contractAccount.Id,
            SBQQ__Quote__c = quote.Id,
            SBQQ__Opportunity__c = opp.Id,
            Status = 'Draft',
            StartDate = Date.today(),
            EndDate = Date.today().addYears(1),
            ContractTerm = 12,
            CurrencyIsoCode = 'USD',
            Business_Unit__c = 'Technical Ship Management',
            Billing_Frequency__c = 'Annual',
            Payment_Terms__c = '30 Days',
            Renewal_Month__c = 'January',
            SBQQ__RenewalTerm__c = 12,
            Next_Renewal_Date__c = Date.today().addYears(1),
            No_of_Installations__c = 1
        );
        insert contr;

        Package__c pack = new Package__c(
            Name = 'Pack-1',
            Contract__c = contr.Id,
            Quote__c = quote.Id,
            Products__c = 'Coverage Product;Addon',
            Installation_Quantity__c = 2,
            InstallationCost__c = 250
        );
        insert pack;

        Installation__c inst = new Installation__c(
            Contract__c = contr.Id,
            Package__c = pack.Id,
            Contract_Customer__c = contractAccount.Id,
            Invoice_Account__c = invoiceAccount.Id,
            Installation_Order_Status__c = 'Active',
            CurrencyIsoCode = 'USD',
            Installation_Price__c = 500
        );
        insert inst;

        Installation_Line__c il = new Installation_Line__c(
            Name = 'Line-1',
            Installation__c = inst.Id,
            Product__c = prod.Id
        );
        insert il;
    }

    @IsTest
    static void test_ControllerBuildsWrappers() {
        Contract contr = [SELECT Id FROM Contract LIMIT 1];

        PageReference pr = Page.ContractOverviewDocPDF;
        Test.setCurrentPage(pr);
        ApexPages.currentPage().getParameters().put('id', contr.Id);

        Test.startTest();
        ApexPages.StandardController sc = new ApexPages.StandardController(contr);
        ContractOverviewDocPDFController ctrl = new ContractOverviewDocPDFController(sc);
        Test.stopTest();

        System.assertNotEquals(null, ctrl.contr, 'Contract should be loaded');
        System.assert(ctrl.packWrapList != null && ctrl.packWrapList.size() > 0, 'Package wrappers expected');
        System.assert(ctrl.instList != null && ctrl.instList.size() == 1, 'Installations should be retrieved');
        System.assertEquals('USD', ctrl.currencyIsoCode, 'Currency should follow installation');
        System.assertEquals(250, ctrl.totalInstallationCost, 'Total installation cost should match package cost');
        System.assertEquals(true, ctrl.hasInv, 'Invoice details should be flagged');

        // Emails should convert semicolons to newline characters
        System.assert(ctrl.invWrapList != null && ctrl.invWrapList.size() == 1, 'Invoice wrapper created');
        System.assert(ctrl.invWrapList[0].invEmail.contains('\n'), 'Invoice emails should be newline separated');

        // Date formatting falls back when renewal opportunity is absent
        String expectedFormattedDate = DateTime.newInstance(Date.today().year(), Date.today().month(), Date.today().day()).format('MM/yyyy');
        System.assertEquals(expectedFormattedDate, ctrl.formattedDate, 'Formatted date should reflect today');
        System.assertEquals('Unknown Date', ctrl.formattedRenewalDate, 'Renewal date fallback expected');
        System.assert(ctrl.version >= 1, 'Version counter should be initialised');
    }

    @IsTest
    static void test_FormatDateWithOrdinal() {
        Date marchFirst = Date.newInstance(2024, 3, 1);
        Date marchEleventh = Date.newInstance(2024, 3, 11);

        String formattedFirst = ContractOverviewDocPDFController.formatDateWithOrdinal(marchFirst);
        String formattedEleventh = ContractOverviewDocPDFController.formatDateWithOrdinal(marchEleventh);

        System.assertEquals('1st March 2024', formattedFirst, '1 should use st suffix');
        System.assertEquals('11th March 2024', formattedEleventh, '11 should use th suffix');
    }
}