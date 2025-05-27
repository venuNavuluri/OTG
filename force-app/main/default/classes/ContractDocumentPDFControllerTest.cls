@IsTest
public class ContractDocumentPDFControllerTest
{
    @TestSetUp
    public static void createData()
    {
        Profile prof = [SELECT Id FROM Profile WHERE Name='OTG Sales User'];
        User u = (User)TestDataFactory.createSObject('User', new Map<String, Object>{
            'profileId' => prof.id,
            'Username' => 'test@rrrr.com..otguatProd4'
        });

        Default_Account_Owner_Settings__c da = (Default_Account_Owner_Settings__c)TestDataFactory.createSObject('Default_Account_Owner_Settings__c', new Map<String, Object>{
            'EMEA_Default_Owner_ID__c' => u.id
        });
        
        Country_Mapping__c cm = new Country_Mapping__c();
        cm.Name = 'Test';
        cm.Sales_Region__c = 'Americas';
        insert cm;
        
        Account acc = new Account();
        acc.Name = 'Test';
        acc.Account_Status__c = 'Unverified';
        acc.AccountSource = 'Cross Department Referral';
        acc.Address1__c = 'Test';
        acc.Town_City__c = 'Texas';
        acc.Country__c = cm.Id;
        acc.Account_Segmentation__c = 'Unknown';
        acc.Customer_Type__c = 'Charity';
        acc.OwnerId = u.Id;
        insert acc;
        
        Account invAcc = new Account(
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Invoice Account').getRecordTypeId(),
            Name = 'Test Inv',
            Company__c = 'Test',
            CurrencyIsoCode = 'USD',
            Invoice_Emails__c = 'Test@test.com',
            Town_City__c = 'Town',
            B2B_Account__c = acc.Id,
            Country__c = cm.Id
        );
        insert invAcc;
        
        Opportunity opp = new Opportunity(
            Name = 'Test',
            LeadSource = 'Cross Department Referral',
            Business_Unit__c = 'Fleet',
            Sales_Type__c = 'Subscription',
            AccountId = acc.Id,
            CloseDate = Date.today() + 90,
            StageName = 'Prospecting & Qualifying',
            Amount = 1000
            //Legal_Entity__c = 
        );
        insert opp;
        
        Product2 prd = (Product2)TestDataFactory.createSObject('Product2', new Map<String, Object>());
        /*PriceBook2 pb = (PriceBook2)TestDataFactory.createSObject('PriceBook2', new Map<String, Object>{
            'Name' => 'Standard Price Book'
        });*/
        PriceBookEntry pbe = (PriceBookEntry)TestDataFactory.createSObject('PriceBookEntry', new Map<String, Object>{
            'Product2Id' => prd.Id,
                'Pricebook2Id' => Test.getStandardPriceBookId(),
                'IsActive' => TRUE
        });
        
        Contact con = new Contact();
        con.LastName = 'Test con';
        con.AccountId = acc.Id;
        con.Job_Role__c = 'Crew / Seafarer';
        insert con;
        
        SBQQ__Quote__c qt = (SBQQ__Quote__c)TestDataFactory.createSObject('SBQQ__Quote__c', new Map<String, Object>{
            'SBQQ__SubscriptionTerm__c' => 12,
            'SBQQ__Account__c' => acc.Id,
            'SBQQ__Opportunity2__c' => opp.Id,
            'SBQQ__BillingFrequency__c' => 'Annual',
            'Agreement_Type__c' => 'Asset Based Installation',
            'SBQQ__Primary__c' => TRUE,
            'SBQQ__PricebookId__c' => Test.getStandardPriceBookId()
                });
        
        SBQQ__QuoteLineGroup__c sbqlg = (SBQQ__QuoteLineGroup__c)TestDataFactory.createSObject('SBQQ__QuoteLineGroup__c', new Map<String, Object>{
            //'Package__c' => pack.id,
                'SBQQ__Quote__c' => qt.id,
                'Installation_Quantity__c' => 1
        });
        
        SBQQ__QuoteLine__c sbql = (SBQQ__QuoteLine__c)TestDataFactory.createSObject('SBQQ__QuoteLine__c', new Map<String, Object>{
            'SBQQ__Quote__c' => qt.Id,
                'SBQQ__Product__c' => prd.Id,
                'SBQQ__Group__c' => sbqlg.Id,
                'SBQQ__PricebookEntryId__c' => pbe.Id
        });
        
        //SBQQ__Quote__c qt = [SELECT Id, Name, SBQQ__Status__c FROM SBQQ__Quote__c ORDER BY CreatedDate DESC LIMIT 1];
        qt.SBQQ__Status__c = 'Approved';
        update qt;
        
        List<Package__c> packList = [SELECT Id, Name, Installation_Quantity__c,Products__c FROM Package__c WHERE Quote__c = :qt.Id];
        System.debug('packList --> ' + packList);
        packList[0].Installation_Quantity__c = 1;
        packList[0].Products__c = 'Product A;Product B';
        packList[1].Installation_Quantity__c = 1;
        packList[1].Products__c = 'Product A;Product B';
        update packList;
        
        Vessel__c ves1 = (Vessel__c)TestDataFactory.createSObject('Vessel__c', new Map<String, Object>{
            'Name' => 'Test1',
                'Vessel_IMO__c' => '123'
        });
        Vessel__c ves2 = (Vessel__c)TestDataFactory.createSObject('Vessel__c', new Map<String, Object>{
            'Name' => 'Test2',
                'Vessel_IMO__c' => '1234'
        });
        
        Installation__c inst1 = (Installation__c)TestDataFactory.createSObject('Installation__c', new Map<String, Object>{
            //'Contract__c' => sbq.SBQQ__Account__c,
            'Package__c' => packList[0].id,
            'Vessel_Name__c' => ves1.id,
                'Quote__c' => qt.Id,
                'Contract_Customer__c' => acc.Id,
                'Invoice_Account__c' => invAcc.Id
        });
        Installation__c inst2 = (Installation__c)TestDataFactory.createSObject('Installation__c', new Map<String, Object>{
            //'Contract__c' => sbq.SBQQ__Account__c,
            'Package__c' => packList[1].id,
            'Vessel_Name__c' => ves2.id,
                'Quote__c' => qt.Id,
                'Contract_Customer__c' => acc.Id,
                'Invoice_Account__c' => invAcc.Id
        });
        
        qt.SBQQ__Ordered__c = TRUE;
        try
        {
            qt.Installation__c = inst1.Id;
            System.debug('qt --> ' + qt);
            update qt;
        }
        catch(Exception ex)
        {
            System.debug('ex --> ' + ex.getStackTraceString());
            System.debug('ex --> ' + ex);
        }
       // Order ord = [SELECT Id, Name FROM Order WHERE SBQQ__Quote__c = :qt.Id];
       // ord.Status = 'Activated';
      //  ord.SBQQ__Contracted__c = TRUE;
      //  update ord;//
        
        Contract contr = (Contract)TestDataFactory.createSObject('Contract', new Map<String, Object>{
            'SBQQ__Quote__c' => qt.Id,
            'AccountId' => acc.Id,
            'SBQQ__Opportunity__c' => opp.Id,
            'Billing_Frequency__c' => 'Annual',
            //'Agreement_Type__c' => 'Asset Based Installation',
            //'SBQQ__Order__c' => ord.Id,
                'StartDate' => Date.today(),
                'EndDate' => Date.today().addDays(365),
                'ContractTerm' => 12
            //'SBQQ__OpportunityPricebookId__c' => Test.getStandardPriceBookId()
                });
    }
    @IsTest
    static void test1() {
        PageReference pageRef = Page.ContractDocumentPDF;
        Test.setCurrentPage(pageRef);
        
        SBQQ__Quote__c qt = [SELECT Id, Name FROM SBQQ__Quote__c LIMIT 1];
        ApexPages.StandardController sc = new  ApexPages.StandardController(qt);
        ContractDocumentPDFController ctrl = new ContractDocumentPDFController(sc);
        
        GenerateDocumentController.saveAsDocument(qt.Id);
        
    }
    
    @IsTest
    static void test2() {
        PageReference pageRef = Page.ContractDocumentPDF;
        Test.setCurrentPage(pageRef);
        
        Contract contr = [SELECT Id, Name FROM Contract LIMIT 1];
        ApexPages.StandardController sc = new  ApexPages.StandardController(contr);
        ContractOverviewDocPDFController ctrl = new ContractOverviewDocPDFController(sc);
        
        Test.startTest();
        GenerateDocumentController.saveAsDocument(contr.Id);
        GenerateDocumentController.saveAsDocument(contr.Id);
        Test.stopTest();
        
    }
    
     @IsTest
    public static void testFormatDateWithOrdinal() {
        // Test Case 1: Test a normal date
        Date inputDate1 = Date.newInstance(2024, 12, 13); // 13th December 2024
        String result1 = ContractDocumentPDFController.formatDateWithOrdinal(inputDate1);
        System.assertEquals('13th December 2024', result1, 'The formatted date is incorrect.');

        // Test Case 2: Test a date ending with "1"
        Date inputDate2 = Date.newInstance(2024, 12, 1); // 1st December 2024
        String result2 = ContractDocumentPDFController.formatDateWithOrdinal(inputDate2);
        System.assertEquals('1st December 2024', result2, 'The formatted date is incorrect.');

        // Test Case 3: Test a date ending with "2"
        Date inputDate3 = Date.newInstance(2024, 12, 2); // 2nd December 2024
        String result3 = ContractDocumentPDFController.formatDateWithOrdinal(inputDate3);
        System.assertEquals('2nd December 2024', result3, 'The formatted date is incorrect.');

        // Test Case 4: Test a date ending with "3"
        Date inputDate4 = Date.newInstance(2024, 12, 3); // 3rd December 2024
        String result4 = ContractDocumentPDFController.formatDateWithOrdinal(inputDate4);
        System.assertEquals('3rd December 2024', result4, 'The formatted date is incorrect.');

        // Test Case 5: Test a date in the teens
        Date inputDate5 = Date.newInstance(2024, 12, 11); // 11th December 2024
        String result5 = ContractDocumentPDFController.formatDateWithOrdinal(inputDate5);
        System.assertEquals('11th December 2024', result5, 'The formatted date is incorrect.');

        Date inputDate6 = Date.newInstance(2024, 12, 13); // 13th December 2024
        String result6 = ContractDocumentPDFController.formatDateWithOrdinal(inputDate6);
        System.assertEquals('13th December 2024', result6, 'The formatted date is incorrect.');

        // Test Case 6: Test end of month
        Date inputDate7 = Date.newInstance(2024, 12, 31); // 31st December 2024
        String result7 = ContractDocumentPDFController.formatDateWithOrdinal(inputDate7);
        System.assertEquals('31st December 2024', result7, 'The formatted date is incorrect.');
    }
    @IsTest
    static void testWrapperModels() {
        // Test PackageWrapper
        ContractOverviewDocPDFController.PackageWrapper packWrap = new ContractOverviewDocPDFController.PackageWrapper();
        packWrap.packageName = 'Test Package';
        packWrap.annualCost = 100;
        packWrap.installationCost = 80;
        packWrap.previousCost = 90;
        packWrap.installationQuantity = 2;
        packWrap.productWrapList = new List<ContractOverviewDocPDFController.ProductWrapper>();
        
        // Test ProductWrapper
        ContractOverviewDocPDFController.ProductWrapper prodWrap = new ContractOverviewDocPDFController.ProductWrapper();
        prodWrap.productName = 'Test Product';
        prodWrap.annualCost = 100;
        prodWrap.installationCost = 80;
        prodWrap.previousCost = 90;
        prodWrap.removeFromPackage = false;
        prodWrap.qlquantity = 2;
        prodWrap.instQuantity = 2;
        
        packWrap.productWrapList.add(prodWrap);
        
        // Test InvoiceWrapper
        ContractOverviewDocPDFController.InvoiceWrapper invWrap = new ContractOverviewDocPDFController.InvoiceWrapper();
        invWrap.invAccNumber = 'INV123';
        invWrap.invEmail = 'test@test.com';
        invWrap.invNameAddr = 'Test Address';
    
        // Assert that values are set correctly
        System.assertEquals('Test Package', packWrap.packageName);
        System.assertEquals('Test Product', packWrap.productWrapList[0].productName);
        System.assertEquals('INV123', invWrap.invAccNumber);
    }
    
    @IsTest
    static void testFormatDateWithOrdinal_FromOverviewController() {
        // Case: Day = 1 → 1st
        Date date1 = Date.newInstance(2024, 1, 1);
        String result1 = ContractOverviewDocPDFController.formatDateWithOrdinal(date1);
        System.assertEquals('1st January 2024', result1);
    
        // Case: Day = 2 → 2nd
        Date date2 = Date.newInstance(2024, 1, 2);
        String result2 = ContractOverviewDocPDFController.formatDateWithOrdinal(date2);
        System.assertEquals('2nd January 2024', result2);
    
        // Case: Day = 3 → 3rd
        Date date3 = Date.newInstance(2024, 1, 3);
        String result3 = ContractOverviewDocPDFController.formatDateWithOrdinal(date3);
        System.assertEquals('3rd January 2024', result3);
    
        // Case: Day = 4 → 4th
        Date date4 = Date.newInstance(2024, 1, 4);
        String result4 = ContractOverviewDocPDFController.formatDateWithOrdinal(date4);
        System.assertEquals('4th January 2024', result4);
    
        // Case: Day = 11 → 11th (edge case)
        Date date11 = Date.newInstance(2024, 1, 11);
        String result11 = ContractOverviewDocPDFController.formatDateWithOrdinal(date11);
        System.assertEquals('11th January 2024', result11);
    
        // Case: Day = 13 → 13th (edge case)
        Date date13 = Date.newInstance(2024, 1, 13);
        String result13 = ContractOverviewDocPDFController.formatDateWithOrdinal(date13);
        System.assertEquals('13th January 2024', result13);
    
        // Case: Day = 21 → 21st
        Date date21 = Date.newInstance(2024, 1, 21);
        String result21 = ContractOverviewDocPDFController.formatDateWithOrdinal(date21);
        System.assertEquals('21st January 2024', result21);
    
        // Case: Day = 22 → 22nd
        Date date22 = Date.newInstance(2024, 1, 22);
        String result22 = ContractOverviewDocPDFController.formatDateWithOrdinal(date22);
        System.assertEquals('22nd January 2024', result22);
    
        // Case: Day = 23 → 23rd
        Date date23 = Date.newInstance(2024, 1, 23);
        String result23 = ContractOverviewDocPDFController.formatDateWithOrdinal(date23);
        System.assertEquals('23rd January 2024', result23);
    }
    
}