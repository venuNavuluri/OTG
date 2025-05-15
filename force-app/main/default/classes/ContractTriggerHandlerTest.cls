@IsTest
public class ContractTriggerHandlerTest
{
    @TestSetUp
    public static void createData()
    {
        /*SBQQ__Quote__c sbq = (SBQQ__Quote__c)TestDataFactory.createSObject('SBQQ__Quote__c', new Map<String, Object>{});

        Package__c pack = (Package__c)TestDataFactory.createSObject('Package__c', new Map<String, Object>{
            'Quote__c' => sbq.Id
        });*/
        
        VRConfiguration__c settings = VRConfiguration__c.getOrgDefaults();
        settings.Quote_Ordered_Validation__c = TRUE;
        upsert settings;
        
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
        
        /*List<SBQQ__QuoteLine__c> qlList = [SELECT Id, Name, SBQQ__Product__c, SBQQ__PriceBookEntryId__c FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c = :qt.Id];
        List<PriceBookEntry> pbeList = [SELECT Id, Product2Id, PriceBook2Id FROM PriceBookEntry WHERE Product2Id = :qlList[0].SBQQ__Product__c];
        System.debug('pbeList --> ' + pbeList);
        qlList[0].SBQQ__PriceBookEntryId__c = [SELECT Id, Product2Id, PriceBook2Id FROM PriceBookEntry WHERE Product2Id = :qlList[0].SBQQ__Product__c].Id;
        update qlList;
        System.debug('qlList --> ' + qlList);
        System.debug('qlList --> ' + qlList.size());
        
        List<Installation__c> instList = [SELECT Id, Name, Package__r.Installation_Quantity__c FROM Installation__c WHERE Quote__c = :qt.Id];
        System.debug('instList --> ' + instList);
        System.debug('int qty 1 --> ' + instList[0].Package__r.Installation_Quantity__c);
        System.debug('int qty 2 --> ' + instList[1].Package__r.Installation_Quantity__c);*/
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
        Order ord = [SELECT Id, Name FROM Order WHERE SBQQ__Quote__c = :qt.Id];
        ord.Status = 'Activated';
        ord.SBQQ__Contracted__c = TRUE;
        update ord;
        
        /*Contract contr = (Contract)TestDataFactory.createSObject('Contract', new Map<String, Object>{
            'SBQQ__Quote__c' => qt.Id,
            'AccountId' => acc.Id,
            'SBQQ__Opportunity__c' => opp.Id,
            'Billing_Frequency__c' => 'Annual',
            //'Agreement_Type__c' => 'Asset Based Installation',
            'SBQQ__Order__c' => ord.Id,
                'StartDate' => Date.today(),
                'EndDate' => Date.today().addDays(365),
                'ContractTerm' => 12
            //'SBQQ__OpportunityPricebookId__c' => Test.getStandardPriceBookId()
                });*/
    }
    
    @IsTest
    public static void testDupInst()
    {
        List<Installation__c> instList = [SELECT Id, Name, Quote__c, Vessel_Name__c, Installation_Type__c, Package__c FROM Installation__c];
        List<Installation__c> newInstList = new List<Installation__c>();
        for(Installation__c inst : instList)
        {
            inst.Installation_Order_Status__c = 'Active';
        }
        update instList;
        for(Installation__c inst : instList)
        {
            newInstList.add(new Installation__c(
                Quote__c = inst.Quote__c,
                Package__c = inst.Package__c,
                Vessel_Name__c = inst.Vessel_Name__c,
                Installation_Type__c = inst.Installation_Type__c
            ));
        }
        Database.saveResult[] srList = Database.insert(newInstList, false);
        for(Database.saveResult sr : srList)
        {
            for(Database.Error er : sr.getErrors())
            {
                System.debug('err --> ' + er.getMessage());
            }
        }
    }
    
    @IsTest
    public static void test1()
    {
        Test.startTest();
        Contract con = [SELECT Id, Name FROM Contract ORDER BY CreatedDate DESC LIMIT 1];
        con.Status = 'Activated';
        update con;
        System.debug('con --> ' + con);
        /*con.SBQQ__RenewalQuoted__c = TRUE;
        con.SBQQ__RenewalForecast__c = TRUE;
        update con;*/
        SBQQ__Quote__c qt = [SELECT Id, Name FROM SBQQ__Quote__c ORDER BY CreatedDate LIMIT 1];
        SBQQ__Quote__c qtClone = qt.clone();
        qtClone.SBQQ__MasterContract__c = con.Id;
        qtClone.SBQQ__Type__c = 'Amendment';
        insert qtClone;
        
        //new QuoteTriggerHandler().createQuoteLineGroups(new Map<Id, SBQQ__Quote__c>{qtClone.Id => qtClone});
        Test.stopTest();
    }
    
    @IsTest
public static void test2() {
    Test.startTest();

    // Fetch contract
    Contract con = [SELECT Id, Name, SBQQ__Quote__c FROM Contract ORDER BY CreatedDate DESC LIMIT 1];

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
            SBQQ__NetPrice__c = 100,
            SBQQ__Quantity__c =1
        ));
    }

    // Bulk insert subscriptions
    insert subscriptions;

    // Fetch installation lines in a single query
    List<Installation_Line__c> instLineList = [
        SELECT Id, Name, Installation__r.Installation_Start_Date__c, Installation__r.Installation_End_Date__c
        FROM Installation_Line__c 
        WHERE Installation__r.Contract__c = :con.Id
    ];

    // Fetch installations
    List<Installation__c> instList = [
        SELECT Id, Name, Contract__c, Installation_Start_Date__c, Installation_End_Date__c
        FROM Installation__c 
        WHERE Contract__c = :con.Id
    ];

    // Bulk update installations
    for (Installation__c inst : instList) {
        inst.Installation_Start_Date__c = Date.today();
        inst.Installation_End_Date__c = Date.today().addDays(364);
        inst.Installation_Order_Status__c = 'Active';
    }
    update instList;

    // Bulk update installation lines
    for (Installation_Line__c instLine : instLineList) {
        instLine.Start_Date__c = Date.today();
        instLine.End_Date__c = Date.today().addDays(364);
    }
    update instLineList;

    // Avoid querying inside loops, bulk insert Sales Order records
    List<Id> instIdList = new List<Id>();
    for (Installation__c inst : instList) {
        instIdList.add(inst.Id);
    }

    // Fetch and process sales orders
    List<Sales_Order__c> soList = [
        SELECT Id, Name, Start_Date__c, End_Date__c 
        FROM Sales_Order__c
        WHERE Installation__c IN :instIdList
    ];

    List<Sales_Order_Item__c> soiList = [
        SELECT Id, Name, Sales_Order__c 
        FROM Sales_Order_Item__c
        WHERE Sales_Order__c IN :soList
    ];

    // Bulk update Sales Orders
    for (Sales_Order__c so : soList) {
        so.Status__c = 'Billed';
    }
    update soList;

    // Bulk update Sales Order Items
    for (Sales_Order_Item__c soi : soiList) {
        soi.Amount__c = 1000;
    }
    update soiList;

    Test.stopTest();
}
    
    @IsTest
    public static void test21()
    {
        Test.startTest();
        Contract con = [SELECT Id, Name, SBQQ__Quote__c FROM Contract ORDER BY CreatedDate DESC LIMIT 1];
        System.debug('con --> ' + con);
        List<Package__c> pack = [SELECT Id, Name FROM Package__c WHERE Quote__c = :con.SBQQ__Quote__c];
        SBQQ__Subscription__c sub1 = (SBQQ__Subscription__c)TestDataFactory.createSObject('SBQQ__Subscription__c', new Map<String, Object>{
            'Package__c' => pack[0].id,
                'SBQQ__Contract__c' => con.Id,
                'SBQQ__SubscriptionStartDate__c' => Date.today(),
                'SBQQ__SubscriptionEndDate__c' => Date.today().addDays(365),
                'SBQQ__NetPrice__c' => 100
                });
        SBQQ__Subscription__c sub2 = (SBQQ__Subscription__c)TestDataFactory.createSObject('SBQQ__Subscription__c', new Map<String, Object>{
            'Package__c' => pack[1].id,
                'SBQQ__Contract__c' => con.Id,
                'SBQQ__SubscriptionStartDate__c' => Date.today(),
                'SBQQ__SubscriptionEndDate__c' => Date.today().addDays(365),
                'SBQQ__NetPrice__c' => 100
                });
        List<Installation_Line__c> instLineList = [SELECT Id, Name, Installation__r.Installation_Start_Date__c, Installation__r.Installation_End_Date__c FROM Installation_Line__c WHERE Installation__r.Contract__c = :con.Id];
        List<Installation__c> instList = [SELECT Id, Name, Contract__c, Installation_Start_Date__c, Installation_End_Date__c FROM Installation__c WHERE Contract__c = :con.Id];
        List<Id> instIdList = new List<Id>();
        for(Installation__c inst : instList)
        {
            instIdList.add(inst.Id);
        }
        CreateInstallationsController.createInstallationLines(new List<SBQQ__Subscription__c>{sub1, sub2}, instIdList);
        instList[0].Installation_Start_date__c = Date.today();
        instList[0].Installation_End_date__c = Date.today().addDays(364);
        instList[0].Installation_Order_Status__c = 'Active';
        instList[1].Installation_Start_date__c = Date.today();
        instList[1].Installation_End_date__c = Date.today().addDays(364);
        instList[1].Installation_Order_Status__c = 'Active';
        update instList;
        System.debug('instList --> ' + instList);
        if(!instLineList.isEmpty())
        {
            instLineList[0].Start_Date__c = Date.today();
            instLineList[0].End_Date__c = Date.today().addDays(364);
            instLineList[1].Start_Date__c = Date.today();
            instLineList[1].End_Date__c = Date.today().addDays(364);
            update instLineList;
            System.debug('instLineList --> ' + instLineList);
        }
        
        /*List<Id> instIdList = new List<Id>();
        for(Installation__c inst : instList)
        {
            instIdList.add(inst.Id);
        }*/
        Date earliestStartDate = Date.today();
        Date latestEndDate = Date.today().addDays(364);
        System.debug('earliestStartDate --> ' + earliestStartDate);
        System.debug('latestEndDate --> ' + latestEndDate);
        List<Installation_Line__c> installationLines = [
            SELECT Id, Name, Installation__c, Product__c, Quote_Line__c, CurrencyIsoCode, 
            Net_Total__c, Subscription__c, Start_Date__c, End_Date__c 
            FROM Installation_Line__c 
            WHERE Installation__c IN :instIdList AND Start_Date__c >= :earliestStartDate AND End_Date__c <= :latestEndDate
        ];
        
        System.debug('installationLines test --> ' + installationLines);
        
        //CreateSalesOrders.createSORecords(con.Id);
        CreateSalesOrderService.createSORecords(instList);
        
        List<Sales_Order__c> soList = [SELECT Id, Name FROM Sales_Order__c WHERE Installation__c IN (:instList[0].Id, :instList[1].Id)];
        System.debug('soList --> ' + soList);
        List<Sales_Order_Item__c> soiList = [SELECT Id, Name, Sales_Order__c FROM Sales_Order_Item__c WHERE Sales_Order__c = :soList];
        for(Sales_Order_Item__c soi : soiList)
        {
            soi.Amount__c = 1000;
        }
        update soiList;
        System.debug('soiList --> ' + soiList);
        soList[0].Status__c = 'Billed';
        //soList[1].Status__c = 'Unbilled';
        update soList;
        List<Sales_Order_Item__c> oldSOItems = [
                SELECT Id, Sales_Order__c, Amount__c, CurrencyIsoCode, Installation_Line__c, Name,
                       Sales_Order__r.Start_Date__c, Sales_Order__r.End_Date__c
                FROM Sales_Order_Item__c 
                WHERE Sales_Order__r.Installation__c IN (:instList[0].Id, :instList[1].Id)
            ];
        System.debug('oldSOItems --> ' + oldSOItems);
        if(!oldSOItems.isEmpty())
        {
            Map<Id, Id> soMap = new Map<Id, Id>();
            soMap.put(oldSOItems[0].Sales_Order__c, oldSOItems[1].Sales_Order__c);
            //
            List<Sales_Order_Item__c> oldSOItems1 = [
                SELECT Id, Sales_Order__c, Amount__c, CurrencyIsoCode, Installation_Line__c, Name,
                Sales_Order__r.Start_Date__c, Sales_Order__r.End_Date__c
                FROM Sales_Order_Item__c 
                WHERE Sales_Order__c IN :soMap.keySet()
            ];
            
            System.debug('oldSOItems1 --> ' + oldSOItems1);
            
            if (oldSOItems1.isEmpty()) {
                return;
            }
            
            List<Sales_Order_Item__c> newSOItems = new List<Sales_Order_Item__c>();
            
            for (Sales_Order_Item__c oldSOItem : oldSOItems1) {
                Id newSOId = soMap.get(oldSOItem.Sales_Order__c);
                if (newSOId != null) {
                    Decimal totalDays = oldSOItem.Sales_Order__r.Start_Date__c.daysBetween(oldSOItem.Sales_Order__r.End_Date__c);
                    Decimal remainingDays = Date.today().daysBetween(oldSOItem.Sales_Order__r.End_Date__c);
                    Decimal proratedAmount = (oldSOItem.Amount__c / totalDays) * remainingDays;
                    
                    newSOItems.add(new Sales_Order_Item__c(
                        Sales_Order__c = newSOId,
                        Amount__c = proratedAmount.abs() * -1,
                        CurrencyIsoCode = oldSOItem.CurrencyIsoCode,
                        Installation_Line__c = oldSOItem.Installation_Line__c,
                        Name = oldSOItem.Name
                    ));
                }
            }
            
            if (!newSOItems.isEmpty()) {
                insert newSOItems;
            }
            //
            InstallationTriggerHandler.createSalesOrderItems(soMap);
        }
        Test.stopTest();
    }
    
    @IsTest
    public static void test3()
    {
        CreateSalesOrderService.getBillingCycleMonths('Semiannual');
        CreateSalesOrderService.getBillingCycleMonths('Quarterly');
        CreateSalesOrderService.getBillingCycleMonths('Monthly');
        CreateSalesOrderService.getBillingCycleMonths('');
    }
    
    @IsTest
    public static void test4()
    {
        Test.startTest();
        Contract con = [SELECT Id, Name, SBQQ__Quote__c FROM Contract ORDER BY CreatedDate DESC LIMIT 1];
        System.debug('con --> ' + con);
        List<Package__c> pack = [SELECT Id, Name FROM Package__c WHERE Quote__c = :con.SBQQ__Quote__c];
        SBQQ__Subscription__c sub1 = (SBQQ__Subscription__c)TestDataFactory.createSObject('SBQQ__Subscription__c', new Map<String, Object>{
            'Package__c' => pack[0].id,
                'SBQQ__Contract__c' => con.Id,
                'SBQQ__SubscriptionStartDate__c' => Date.today(),
                'SBQQ__SubscriptionEndDate__c' => Date.today().addDays(365),
                'SBQQ__NetPrice__c' => 1000,
                'SBQQ__Quantity__c' => 1
                });
        SBQQ__Subscription__c sub2 = (SBQQ__Subscription__c)TestDataFactory.createSObject('SBQQ__Subscription__c', new Map<String, Object>{
            'Package__c' => pack[1].id,
                'SBQQ__Contract__c' => con.Id,
                'SBQQ__SubscriptionStartDate__c' => Date.today(),
                'SBQQ__SubscriptionEndDate__c' => Date.today().addDays(365),
                'SBQQ__NetPrice__c' => 1000,
                'SBQQ__Quantity__c' => 1
                });
        
        List<Installation__c> instList = [SELECT Id, Name, Contract__c, Installation_Start_Date__c, Installation_End_Date__c FROM Installation__c WHERE Contract__c = :con.Id];
        List<Id> instIdList = new List<Id>();
        for(Installation__c inst : instList)
        {
            instIdList.add(inst.Id);
        }
        CreateInstallationsController.createInstallationLines(new List<SBQQ__Subscription__c>{sub1, sub2}, instIdList);
        List<Installation_Line__c> instLineList = [SELECT Id, Name, Installation__r.Installation_Start_Date__c, Installation__r.Installation_End_Date__c FROM Installation_Line__c WHERE Installation__r.Contract__c = :con.Id];
        instList[0].Installation_Start_date__c = Date.today();
        instList[0].Installation_End_date__c = Date.today().addDays(364);
        instList[0].Installation_Order_Status__c = 'Active';
        instList[1].Installation_Start_date__c = Date.today();
        instList[1].Installation_End_date__c = Date.today().addDays(364);
        instList[1].Installation_Order_Status__c = 'Active';
        update instList;
        System.debug('instList --> ' + instList);
        if(!instLineList.isEmpty())
        {
            instLineList[0].Start_Date__c = Date.today();
            instLineList[0].End_Date__c = Date.today().addDays(364);
            instLineList[1].Start_Date__c = Date.today();
            instLineList[1].End_Date__c = Date.today().addDays(364);
            update instLineList;
            System.debug('instLineList --> ' + instLineList);
        }
        
        CreateSalesOrders.createSORecords(con.Id);
        Test.stopTest();
    }
    
    @IsTest
    public static void test5()
    {
        Test.startTest();
        Contract con = [SELECT Id, Name, SBQQ__Quote__c FROM Contract ORDER BY CreatedDate DESC LIMIT 1];
        System.debug('con --> ' + con);
        List<Package__c> pack = [SELECT Id, Name FROM Package__c WHERE Quote__c = :con.SBQQ__Quote__c];
        SBQQ__Subscription__c sub1 = (SBQQ__Subscription__c)TestDataFactory.createSObject('SBQQ__Subscription__c', new Map<String, Object>{
            'Package__c' => pack[0].id,
                'SBQQ__Contract__c' => con.Id,
                'SBQQ__SubscriptionStartDate__c' => Date.today(),
                'SBQQ__SubscriptionEndDate__c' => Date.today().addDays(365),
                'SBQQ__NetPrice__c' => 1000,
                'SBQQ__Quantity__c' => 1
                });
        SBQQ__Subscription__c sub2 = (SBQQ__Subscription__c)TestDataFactory.createSObject('SBQQ__Subscription__c', new Map<String, Object>{
            'Package__c' => pack[1].id,
                'SBQQ__Contract__c' => con.Id,
                'SBQQ__SubscriptionStartDate__c' => Date.today(),
                'SBQQ__SubscriptionEndDate__c' => Date.today().addDays(365),
                'SBQQ__NetPrice__c' => 1000,
                'SBQQ__Quantity__c' => 1
                });
        //CreateInstallationsController.createInstallationLines(new List<SBQQ__Subscription__c>{sub1, sub2});
        //List<Installation_Line__c> instLineList = [SELECT Id, Name, Installation__r.Installation_Start_Date__c, Installation__r.Installation_End_Date__c FROM Installation_Line__c WHERE Installation__r.Contract__c = :con.Id];
        List<Installation__c> instList = [SELECT Id, Name, Contract__c, Installation_Start_Date__c, Installation_End_Date__c FROM Installation__c WHERE Contract__c = :con.Id];
        instList[0].Installation_Start_date__c = Date.today();
        instList[0].Installation_End_date__c = Date.today().addDays(364);
        instList[0].Installation_Order_Status__c = 'Active';
        /*instList[1].Installation_Start_date__c = Date.today();
        instList[1].Installation_End_date__c = Date.today().addDays(364);
        instList[1].Installation_Order_Status__c = 'Active';*/
        update instList;
        System.debug('instList --> ' + instList);
        
        List<Id> instIdList = new List<Id>();
        for(Installation__c inst : instList)
        {
            instIdList.add(inst.Id);
        }
        
        CreateSalesOrders.createSORecordsInst(instList[0].Id);
        Test.stopTest();
    }
    
    @IsTest
    public static void test6()
    {
        Test.startTest();
        Contract con = [SELECT Id, Name, SBQQ__Quote__c, SBQQ__Opportunity__c, Previous_Contract__c FROM Contract WHERE SBQQ__Quote__c != NULL AND SBQQ__Opportunity__c != NULL AND Previous_Contract__c = NULL LIMIT 1];
        
        SBQQ__Quote__c qt = new SBQQ__Quote__c(
            Id = con.SBQQ__Quote__c,
            SBQQ__Type__c = 'Renewal'
        );
        update qt;
        
        con.Description = 'test';
        update con;
        Test.stopTest();
    }
    
    @IsTest
    public static void testCalculateCurrentPriceOnQuoteLineGroups() {
        // Step 1: Retrieve the test Quote created in the test setup
        SBQQ__Quote__c testQuote = [
            SELECT Id, Name, SBQQ__Status__c 
            FROM SBQQ__Quote__c 
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];
        
        SBQQ__QuoteLine__c ql = [SELECT Id, Name, SBQQ__Quote__c, Previous_Subscription_Net_Total__c, SBQQ__RenewedSubscription__r.Net_Total__c, SBQQ__RenewedSubscription__c, SBQQ__Quantity__c, SBQQ__NetPrice__c FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c = :testQuote.Id];
        ql.SBQQ__NetPrice__c = 100.00;
        update ql;
        System.debug('ql --> ' + ql);

        // Step 2: Update Quote to Approved status to trigger the logic
        testQuote.SBQQ__Status__c = 'Approved';
        update testQuote;

        // Step 4: Call the method to calculate Current_Price__c
        Test.startTest();
        new QuoteTriggerHandler().calculateCurrentPriceOnQuoteLineGroups(new Set<Id>{testQuote.Id});
        Test.stopTest();
        
        ql = [SELECT Id, Name, SBQQ__Quote__c, Previous_Subscription_Net_Total__c, SBQQ__RenewedSubscription__r.Net_Total__c, SBQQ__RenewedSubscription__c FROM SBQQ__QuoteLine__c WHERE Previous_Subscription_Net_Total__c != NULL];
        System.debug('ql --> ' + ql);

        // Step 5: Validate the updated Current_Price__c on QuoteLineGroup
        /*SBQQ__QuoteLineGroup__c updatedQLG = [
            SELECT Id, Current_Price__c 
            FROM SBQQ__QuoteLineGroup__c 
            WHERE SBQQ__Quote__c = :testQuote.Id AND Current_Price__c = 100 LIMIT 1
        ];*/

        //System.assertEquals(100, updatedQLG.Current_Price__c, 'Current_Price__c should match the aggregated Previous_Subscription_Net_Total__c.');
    }
}