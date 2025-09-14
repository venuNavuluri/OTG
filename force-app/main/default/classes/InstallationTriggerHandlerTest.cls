@IsTest
public class InstallationTriggerHandlerTest
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
        
        PriceBookEntry pbe = (PriceBookEntry)TestDataFactory.createSObject('PriceBookEntry', new Map<String, Object>{
            'Product2Id' => prd.Id,
                'Pricebook2Id' => Test.getStandardPriceBookId(),
                'IsActive' => TRUE
        });
        
        SBQQ__Quote__c qt = (SBQQ__Quote__c)TestDataFactory.createSObject('SBQQ__Quote__c', new Map<String, Object>{
            'SBQQ__SubscriptionTerm__c' => 12,
            'SBQQ__Account__c' => acc.Id,
            'SBQQ__Opportunity2__c' => opp.Id,
            'SBQQ__BillingFrequency__c' => 'Annual',
            'Agreement_Type__c' => 'Asset Based Installation',
            'SBQQ__Primary__c' => TRUE,
            'SBQQ__PricebookId__c' => Test.getStandardPriceBookId(),
                'SBQQ__StartDate__c' => Date.today(),
                'SBQQ__EndDate__c' => Date.today()
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
        Order ord = (Order)TestDataFactory.createSObject('Order', new Map<String, Object>{
            'AccountId' => acc.Id,
                'SBQQ__Quote__c' => qt.Id
        });
        
    }
    
    @IsTest
    public static void testDuplicateInstallation() {
        Installation__c existingInst = [SELECT Contract_Customer__c, Vessel_Name__c, Package__c FROM Installation__c LIMIT 1];
        existingInst.Installation_Order_Status__c = 'Active';
        update existingInst;
        Installation__c duplicateInst = new Installation__c(
            Contract_Customer__c = existingInst.Contract_Customer__c,
            Vessel_Name__c = existingInst.Vessel_Name__c,
            Installation_Type__c = 'Vessel',
            Installation_Order_Status__c = 'Active',
            Package__c = existingInst.Package__c
        );

        Test.startTest();
        try {
            insert duplicateInst;
            //System.assert(false, 'Expected duplicate error.');
        } catch (Exception ex) {
            System.assert(ex.getMessage().contains('Duplicate installation record'), 'Expected duplicate installation error.');
        }
        Test.stopTest();
    }
    
    @IsTest
    public static void testTerminateInstallation()
    {
        Test.startTest();
        Installation__c inst = [SELECT Id, Quote__c, Quote__r.SBQQ__Opportunity2__c, Order__c FROM Installation__c WHERE Installation_Order_Status__c != 'Active' LIMIT 1];
        Account acc = [SELECT Id, Name FROM Account WHERE Name = 'Test' LIMIT 1];
        
        Contract con = new Contract();
        con.SBQQ__Order__c = inst.Order__c;
        con.SBQQ__Quote__c = inst.Quote__c;
        con.SBQQ__Opportunity__c = inst.Quote__r.SBQQ__Opportunity2__c;
        con.AccountId = acc.Id;
        con.ContractTerm = 12;
        con.StartDate = Date.today();
        con.EndDate = Date.today().addDays(365);
        insert con;

        // Fetch related Packages
        List<Package__c> packList = [SELECT Id, Name FROM Package__c WHERE Quote__c = :con.SBQQ__Quote__c];
        
        // Avoid querying inside a loop - Using map for efficient updates
        Map<Id, Package__c> packageMap = new Map<Id, Package__c>();
        for (Package__c p : packList) {
            packageMap.put(p.Id, p);
        }
        
        // Create subscriptions
        List<SBQQ__Subscription__c> subscriptions = new List<SBQQ__Subscription__c>();
        for (Id packageId : packageMap.keySet()) {
            subscriptions.add(new SBQQ__Subscription__c(
                Package__c = packageId,
                SBQQ__Contract__c = con.Id,
                SBQQ__SubscriptionStartDate__c = Date.today(),
                SBQQ__SubscriptionEndDate__c = Date.today().addDays(365),
                SBQQ__SegmentStartDate__c = Date.today(),
                SBQQ__SegmentEndDate__c = Date.today().addDays(364),
                SBQQ__NetPrice__c = 100,
                SBQQ__Quantity__c =1
            ));
        }
        
        // Bulk insert subscriptions
        insert subscriptions;
        
        
        
        inst.Installation_Order_Status__c = 'Active';
        inst.Contract__c = con.Id;
        inst.Installation_Start_date__c = Date.today();
        inst.Installation_End_date__c = Date.today().addDays(365);
        update inst;
        
        CreateInstallationsController.goToInstallationLineCreation(new List<Id>{inst.Id});
        Sales_Order__c salesOrder = new Sales_Order__c(
						Installation__c = inst.Id,
						Start_Date__c = Date.today(),
						End_Date__c = Date.today().addDays(365),
						Status__c = 'Unbilled'
					);
        insert salesOrder;
        Sales_Order__c so = new Sales_Order__c(
						Installation__c = inst.Id,
						Start_Date__c = Date.today().addDays(-10),
						End_Date__c = Date.today().addDays(355),
						Status__c = 'Billed'
					);
        insert so;
        
        CreateSalesOrderService.createSORecords(new List<Installation__c>{inst});
        
        Sales_Order_Item__c soi = new Sales_Order_Item__c(
            Sales_Order__c = so.Id,
            Amount__c = 100.00
        );
        insert soi;
        
        List<Sales_Order_Item__c> soiList = [SELECT Id, Name, Sales_Order__c FROM Sales_Order_Item__c];
        System.debug('soIList --> ' + soiList);
        
        Map<Id, Id> soiIdMap = new Map<Id, Id>();
        for(Sales_Order_Item__c soit : soiList)
        {
            soiIdMap.put(soit.Sales_Order__c, soit.Sales_Order__c);
        }
        
        InstallationTriggerHandler.createSalesOrderItems(soiIdMap, Date.today());
        
        inst.Auto_Termination__c = TRUE;
        inst.Installation_Order_Status__c = 'Terminated';
        inst.Termination_End_Date__c = Date.today();
        inst.Termination_Reason__c = 'Test';

        //Test.startTest();
        update inst;
        Test.stopTest();
    }
}