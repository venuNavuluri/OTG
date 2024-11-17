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
            //'Contract__c' => sbq.SBQQ__Account__c,
            'Package__c' => packList[0].id,
            'Vessel_Name__c' => ves1.id,
                'Quote__c' => qt.Id
        });
        Installation__c inst2 = (Installation__c)TestDataFactory.createSObject('Installation__c', new Map<String, Object>{
            //'Contract__c' => sbq.SBQQ__Account__c,
            'Package__c' => packList[1].id,
            'Vessel_Name__c' => ves2.id,
                'Quote__c' => qt.Id
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
        
        Contract contr = (Contract)TestDataFactory.createSObject('Contract', new Map<String, Object>{
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
                });
    }
    
    @IsTest
    public static void test1()
    {
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
        
        new QuoteTriggerHandler().createQuoteLineGroups(new Map<Id, SBQQ__Quote__c>{qtClone.Id => qtClone});
    }
    
    @IsTest
    public static void test2()
    {
        Contract con = [SELECT Id, Name, SBQQ__Quote__c FROM Contract ORDER BY CreatedDate DESC LIMIT 1];
        System.debug('con --> ' + con);
        List<Package__c> pack = [SELECT Id, Name FROM Package__c WHERE Quote__c = :con.SBQQ__Quote__c];
        SBQQ__Subscription__c sub1 = (SBQQ__Subscription__c)TestDataFactory.createSObject('SBQQ__Subscription__c', new Map<String, Object>{
            'Package__c' => pack[0].id,
                'SBQQ__Contract__c' => con.Id,
                'SBQQ__SubscriptionStartDate__c' => Date.today(),
                'SBQQ__SubscriptionEndDate__c' => Date.today().addDays(365)
                });
        SBQQ__Subscription__c sub2 = (SBQQ__Subscription__c)TestDataFactory.createSObject('SBQQ__Subscription__c', new Map<String, Object>{
            'Package__c' => pack[1].id,
                'SBQQ__Contract__c' => con.Id,
                'SBQQ__SubscriptionStartDate__c' => Date.today(),
                'SBQQ__SubscriptionEndDate__c' => Date.today().addDays(365)
                });
        CreateInstallationsController.createInstallationLines(new List<SBQQ__Subscription__c>{sub1, sub2});
        List<Installation_Line__c> instLineList = [SELECT Id, Name, Installation__r.Installation_Start_Date__c, Installation__r.Installation_End_Date__c FROM Installation_Line__c WHERE Installation__r.Contract__c = :con.Id];
        List<Installation__c> instList = [SELECT Id, Name, Contract__c, Installation_Start_Date__c, Installation_End_Date__c FROM Installation__c WHERE Contract__c = :con.Id];
        instList[0].Installation_Start_date__c = Date.today();
        instList[0].Installation_End_date__c = Date.today().addDays(364);
        instList[0].Installation_Order_Status__c = 'Active';
        instList[1].Installation_Start_date__c = Date.today();
        instList[1].Installation_End_date__c = Date.today().addDays(364);
        instList[1].Installation_Order_Status__c = 'Active';
        update instList;
        System.debug('instList --> ' + instList);
        instLineList[0].Start_Date__c = Date.today();
        instLineList[0].End_Date__c = Date.today().addDays(364);
        instLineList[1].Start_Date__c = Date.today();
        instLineList[1].End_Date__c = Date.today().addDays(364);
        update instLineList;
        System.debug('instLineList --> ' + instLineList);
        
        List<Id> instIdList = new List<Id>();
        for(Installation__c inst : instList)
        {
            instIdList.add(inst.Id);
        }
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
        
        List<Sales_Order__c> soList = [SELECT Id, Name FROM Sales_Order__c];
        System.debug('soList --> ' + soList);
        List<Sales_Order_Item__c> soiList = [SELECT Id, Name FROM Sales_Order_Item__c WHERE Sales_Order__c = :soList];
        for(Sales_Order_Item__c soi : soiList)
        {
            soi.Amount__c = 1000;
        }
        update soiList;
        CreateSalesOrderService.calculateProratedAmount(instLineList[0], soList[0]);
        soList[0].Status__c = 'Billed';
        soList[1].Status__c = 'Unbilled';
        update soList;
        instList[0].Installation_Order_Status__c = 'Terminated';
        instList[0].Termination_End_Date__c = Date.today();
        instList[1].Installation_Order_Status__c = 'Terminated';
        instList[1].Termination_End_Date__c = Date.today();
        update instList;
        //CreateInstallationsController.createNewInstRecord(TRUE, pack[0].Id, con.Id, instList[0]);
        
        con.SBQQ__RenewalForecast__c = TRUE;
        con.SBQQ__RenewalQuoted__c = TRUE;
        //update con;
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
        CreateInstallationsController.createInstallationLines(new List<SBQQ__Subscription__c>{sub1, sub2});
        List<Installation_Line__c> instLineList = [SELECT Id, Name, Installation__r.Installation_Start_Date__c, Installation__r.Installation_End_Date__c FROM Installation_Line__c WHERE Installation__r.Contract__c = :con.Id];
        List<Installation__c> instList = [SELECT Id, Name, Contract__c, Installation_Start_Date__c, Installation_End_Date__c FROM Installation__c WHERE Contract__c = :con.Id];
        instList[0].Installation_Start_date__c = Date.today();
        instList[0].Installation_End_date__c = Date.today().addDays(364);
        instList[0].Installation_Order_Status__c = 'Active';
        instList[1].Installation_Start_date__c = Date.today();
        instList[1].Installation_End_date__c = Date.today().addDays(364);
        instList[1].Installation_Order_Status__c = 'Active';
        update instList;
        System.debug('instList --> ' + instList);
        instLineList[0].Start_Date__c = Date.today();
        instLineList[0].End_Date__c = Date.today().addDays(364);
        instLineList[1].Start_Date__c = Date.today();
        instLineList[1].End_Date__c = Date.today().addDays(364);
        update instLineList;
        System.debug('instLineList --> ' + instLineList);
        
        List<Id> instIdList = new List<Id>();
        for(Installation__c inst : instList)
        {
            instIdList.add(inst.Id);
        }
        
        CreateSalesOrders.createSORecords(con.Id);
    }
}