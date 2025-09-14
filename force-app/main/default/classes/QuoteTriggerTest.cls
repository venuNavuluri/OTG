@IsTest
public class QuoteTriggerTest
{
     @TestSetUp
    public static void createTestData()
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
                'SBQQ__PricebookId__c' => Test.getStandardPriceBookId(),
                'SBQQ__StartDate__c' => Date.today()
                });
        
        SBQQ__QuoteLineGroup__c sbqlg = (SBQQ__QuoteLineGroup__c)TestDataFactory.createSObject('SBQQ__QuoteLineGroup__c', new Map<String, Object>{
            //'Package__c' => pack.id,
            'SBQQ__Quote__c' => qt.id,
                'Installation_Quantity__c' => 1
                });
        
        SBQQ__Subscription__c sub1 = (SBQQ__Subscription__c)TestDataFactory.createSObject('SBQQ__Subscription__c', new Map<String, Object>{
            'SBQQ__SubscriptionStartDate__c' => Date.today(),
                'SBQQ__SubscriptionEndDate__c' => Date.today().addDays(365),
                'SBQQ__NetPrice__c' => 100
                });
        
        SBQQ__QuoteLine__c sbql = (SBQQ__QuoteLine__c)TestDataFactory.createSObject('SBQQ__QuoteLine__c', new Map<String, Object>{
            'SBQQ__Quote__c' => qt.Id,
                'SBQQ__Product__c' => prd.Id,
                'SBQQ__Group__c' => sbqlg.Id,
                'SBQQ__PricebookEntryId__c' => pbe.Id,
                'SBQQ__RenewedSubscription__c' =>sub1.Id,
                'SBQQ__NetPrice__c' => 100.00,
                'SBQQ__Quantity__c' => 1
                });
        System.debug('sbql --> ' + sbql);
        
        //SBQQ__Quote__c qt = [SELECT Id, Name, SBQQ__Status__c FROM SBQQ__Quote__c ORDER BY CreatedDate DESC LIMIT 1];
        qt.SBQQ__Status__c = 'Approved';
        update qt;
        
        List<Package__c> packList = [SELECT Id, Name, Installation_Quantity__c FROM Package__c WHERE Quote__c = :qt.Id];
        System.debug('packList --> ' + packList);
        packList[0].Quote_Line_Group__c = sbqlg.Id;
        packList[1].Quote_Line_Group__c = sbqlg.Id;
        packList[0].Installation_Quantity__c = 1;
        packList[1].Installation_Quantity__c = 1;
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
            'Contract_Customer__c' => acc.Id,
                'Package__c' => packList[0].id,
                'Vessel_Name__c' => ves1.id,
                'Quote__c' => qt.Id,
                'Installation_Type__c' => 'Vessel'
                });
        Installation__c inst2 = (Installation__c)TestDataFactory.createSObject('Installation__c', new Map<String, Object>{
            'Contract_Customer__c' => acc.Id,
                'Package__c' => packList[1].id,
                'Vessel_Name__c' => ves2.id,
                'Quote__c' => qt.Id,
                'Installation_Type__c' => 'Vessel'
                });
        
        VRConfiguration__c settings = VRConfiguration__c.getOrgDefaults();
        settings.Quote_Ordered_Validation__c = TRUE;
        upsert settings;
        
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
                
        // Create test contracts with different currencies
        List<Contract> testContracts = new List<Contract>{
            new Contract(
                AccountId = acc.Id,
                Status = 'Draft',
                StartDate = Date.today(),
                ContractTerm = 12,
                CurrencyIsoCode = 'USD',
                OwnerId = u.Id
            ),
                new Contract(
                    AccountId = acc.Id,
                    Status = 'Draft',
                    StartDate = Date.today(),
                    ContractTerm = 12,
                    CurrencyIsoCode = 'EUR',
                    OwnerId = u.Id
                )
                };
                    insert testContracts;
        
        // Activate contracts
        for (Contract c : testContracts) {
            c.Status = 'Activated';
        }
        update testContracts;
        
        // Create test opportunities with different currencies
        List<Opportunity> testOpportunities = new List<Opportunity>{
            new Opportunity(
                Name = 'USD Opportunity - Quote Test',
                AccountId = acc.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30),
                CurrencyIsoCode = 'SGD',
                OwnerId = u.Id,
                Amount = 10000,
                Business_Unit__c = 'Fleet',
                Sales_Type__c = 'Subscription'
            ),
                new Opportunity(
                    Name = 'EUR Opportunity - Quote Test',
                    AccountId = acc.Id,
                    StageName = 'Prospecting',
                    CloseDate = Date.today().addDays(30),
                    CurrencyIsoCode = 'GBP', 
                    OwnerId = u.Id,
                    Amount = 15000,
                    Business_Unit__c = 'Fleet',
                    Sales_Type__c = 'Subscription'
                )
                };
                    insert testOpportunities;
        
        
    }
    
    @IsTest
    public static void test1()
    {
        Test.startTest();
        Order ord = [SELECT Id, Name, AccountId, SBQQ__Quote__c, SBQQ__Quote__r.SBQQ__Opportunity2__c FROM Order WHERE SBQQ__Quote__c != NULL LIMIT 1];
        ord.Status = 'Activated';
        ord.SBQQ__Contracted__c = TRUE;
        //update ord;
        
        Contract con = new Contract();
        con.SBQQ__Order__c = ord.Id;
        con.SBQQ__Quote__c = ord.SBQQ__Quote__c;
        con.SBQQ__Opportunity__c = ord.SBQQ__Quote__r.SBQQ__Opportunity2__c;
        con.AccountId = ord.AccountId;
        insert con;
        
        con.Status = 'Activated';
        update con;
        System.debug('con --> ' + con);
        List<Contract> conList = [SELECT Id, Name FROM Contract WHERE SBQQ__Order__c = :ord.Id];
        System.debug('contList --> ' + conList);
        
        List<Package__c> packList = [SELECT Id, Name, Installation_Quantity__c FROM Package__c WHERE Quote__c = :ord.SBQQ__Quote__c];
        
        Vessel__c ves = (Vessel__c)TestDataFactory.createSObject('Vessel__c', new Map<String, Object>{
            'Name' => 'Test',
                'Vessel_IMO__c' => '123488'
                });
        
        Installation__c inst = (Installation__c)TestDataFactory.createSObject('Installation__c', new Map<String, Object>{
            'Contract_Customer__c' => ord.AccountId,
                'Package__c' => packList[0].id,
                'Vessel_Name__c' => ves.id,
                'Quote__c' => ord.SBQQ__Quote__c,
                'Installation_Type__c' => 'Vessel'
                });
        
        CreateInstallationsController.modifyContract(inst.Id, Date.today(), con.Id, packList[0].Id, FALSE);
        Test.stopTest();
    }
    
    @IsTest
    public static void test2()
    {
        Test.startTest();
        Opportunity opp = [SELECT Id, Name, AccountId FROM Opportunity LIMIT 1];
        Order ord = [SELECT Id, Name, AccountId, SBQQ__Quote__c, SBQQ__Quote__r.SBQQ__Opportunity2__c FROM Order WHERE SBQQ__Quote__c != NULL LIMIT 1];
        /*ord.Status = 'Activated';
ord.SBQQ__Contracted__c = TRUE;
update ord;*/
        
        Contract con = new Contract();
        con.SBQQ__Order__c = ord.Id;
        con.SBQQ__Quote__c = ord.SBQQ__Quote__c;
        con.SBQQ__Opportunity__c = ord.SBQQ__Quote__r.SBQQ__Opportunity2__c;
        con.AccountId = ord.AccountId;
        insert con;
        
        List<Package__c> packList = [SELECT Id, Name, Installation_Quantity__c FROM Package__c WHERE Quote__c = :ord.SBQQ__Quote__c];
        for(Package__c pack : packList)
        {
            pack.Contract__c = con.Id;
        }
        update packList;
        
        SBQQ__Quote__c qt = [SELECT Id, Name, SBQQ__MasterContract__c FROM SBQQ__Quote__c LIMIT 1];
        
        qt.SBQQ__Status__c = 'Approved';
        qt.SBQQ__MasterContract__c = con.Id;
        qt.SBQQ__Type__c = 'Amendment';
        Map<Id, SBQQ__Quote__c> qtMap = new Map<Id, SBQQ__Quote__c>();
        qtMap.put(qt.Id, qt);
        new QuoteTriggerHandler().createQuoteLineGroups(qtMap);
        Test.stopTest();
    }
    
    @IsTest
    public static void testActivateOrder()
    {
        Test.startTest();
        try
        {
            Order ord = [SELECT Id, Name FROM Order LIMIT 1];
            ActivateOrderController.activateOrder(ord.Id, Date.today());
        }
        catch(Exception ex)
        {
            SYstem.debug('ex --> ' + ex);
            SYstem.debug('ex stack --> ' + ex.getStackTraceString());
        }
        Test.stopTest();
    }
    
    @IsTest
    public static void testApproveQuote()
    {
        List<SBQQ__Quote__c> qtList = [SELECT Id, Name, SBQQ__Status__c FROM SBQQ__Quote__c LIMIT 1];
        Map<Id, SBQQ__Quote__c> newQtMap = new Map<Id, SBQQ__Quote__c>();
        newQtMap.put(qtList[0].Id, new SBQQ__Quote__c(Id = qtList[0].Id, SBQQ__Status__c = 'Approved'));
        Map<Id, SBQQ__Quote__c> oldQtMap = new Map<Id, SBQQ__Quote__c>();
        oldQtMap.put(qtList[0].Id, new SBQQ__Quote__c(Id = qtList[0].Id, SBQQ__Status__c = 'Draft'));
        new QuoteTriggerHandler().syncPackageRecords(newQtMap, oldQtMap);
    }
    
    @IsTest
    public static void testUpdateQuoteEndDateFromContractInSetup() {
        // Fetch required existing test data
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contract ctr = [SELECT Id, EndDate FROM Contract WHERE AccountId = :acc.Id LIMIT 1];
        Opportunity opp = [SELECT Id, Name, AccountId FROM Opportunity LIMIT 1];

        // Create quote as Amendment
        SBQQ__Quote__c qt = new SBQQ__Quote__c(
            SBQQ__Account__c = acc.Id,
            SBQQ__Status__c = 'Draft',
            SBQQ__Primary__c = TRUE,
            SBQQ__Type__c = 'Amendment',
            SBQQ__MasterContract__c = ctr.Id,
            SBQQ__StartDate__c = Date.today()
        );
        insert qt;
        
        Test.startTest();
        qt.SBQQ__Status__c = 'Approved';
        update qt;
        qt = [SELECT Id, SBQQ__EndDate__c FROM SBQQ__Quote__c WHERE Id = :qt.Id];
        System.assertEquals(ctr.EndDate, qt.SBQQ__EndDate__c);
        Test.stopTest();
        
    }
    
      @isTest
    static void testAmendmentQuoteWithCurrencyUpdate() {
        // Get test data
        Opportunity usdOpp = [SELECT Id, CurrencyIsoCode FROM Opportunity WHERE CurrencyIsoCode = 'SGD' LIMIT 1];
        Contract usdContract = [SELECT Id  FROM Contract WHERE CurrencyIsoCode = 'USD' LIMIT 1];
        
        Test.startTest();
        VRConfiguration__c settings = VRConfiguration__c.getOrgDefaults();
        settings.Quote_Ordered_Validation__c = TRUE;
        upsert settings;
        // Create amendment quote
        SBQQ__Quote__c testQuote = new SBQQ__Quote__c(
            SBQQ__Type__c = 'Amendment',
            SBQQ__Opportunity2__c = usdOpp.Id,
            SBQQ__MasterContract__c = usdContract.Id,
            CurrencyIsoCode = 'NOK', 
            SBQQ__Account__c = [SELECT Id FROM Account WHERE Name = 'Test' LIMIT 1].Id
        );
        insert testQuote;
        Test.stopTest();
        
        // Verify results
        SBQQ__Quote__c updatedQuote = [SELECT CurrencyIsoCode FROM SBQQ__Quote__c WHERE Id = :testQuote.Id];
        Opportunity updatedOpp = [SELECT CurrencyIsoCode FROM Opportunity  WHERE Id = :usdOpp.Id];
        
        System.assertEquals('USD', updatedQuote.CurrencyIsoCode, 'Quote currency should match contract currency');
        System.assertEquals('USD', updatedOpp.CurrencyIsoCode, 'Opportunity currency should match contract currency');
    }
    
}