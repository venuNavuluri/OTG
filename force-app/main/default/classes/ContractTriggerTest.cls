@IsTest
public class ContractTriggerTest
{
    @TestSetUp
    public static void createData()
    {
        Profile prof = [SELECT Id FROM Profile WHERE Name='OTG Sales User'];
        User u = (User)TestDataFactory.createSObject('User', new Map<String, Object>{
            'profileId' => prof.id,
            'Username' => 'test@rrrr.com..otguatProd4'
        });
        
        VRConfiguration__c settings = VRConfiguration__c.getOrgDefaults();
        settings.Quote_Ordered_Validation__c = TRUE;
        upsert settings;

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
        
        /*Order ord = (Order)TestDataFactory.createSObject('Order', new Map<String, Object>{
            'SBQQ__Quote__c' => qt.Id
        });
        
        /*OrderItem ordIt = (OrderItem)TestDataFactory.createSObject('OrderItem', new Map<String, Object>{
            'OrderId' => ord.Id,
                'Product2Id' => prd.Id
        });*/
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
        
        //con.Status = 'Activated';
        //update con;
        System.debug('con --> ' + con);
        List<Contract> conList = [SELECT Id, Name FROM Contract WHERE SBQQ__Order__c = :ord.Id];
        System.debug('contList --> ' + conList);
        Test.stopTest();
    }
    
    @IsTest
    public static void test2()
    {
        Test.startTest();
        Order ord = [SELECT Id, Name, AccountId, SBQQ__Quote__c, SBQQ__Quote__r.SBQQ__Opportunity2__c FROM Order WHERE SBQQ__Quote__c != NULL LIMIT 1];
        ord.Status = 'Activated';
        ord.SBQQ__Contracted__c = TRUE;
        //update ord;
        SBQQ__Quote__c qt = [SELECT Id, Name, SBQQ__Type__c FROM SBQQ__Quote__c WHERE Id = :ord.SBQQ__Quote__c];
        qt.SBQQ__Type__c = 'Renewal';
        update qt;
        
        Contract con = new Contract();
        con.SBQQ__Order__c = ord.Id;
        con.SBQQ__Quote__c = ord.SBQQ__Quote__c;
        con.SBQQ__Opportunity__c = ord.SBQQ__Quote__r.SBQQ__Opportunity2__c;
        con.AccountId = ord.AccountId;
        insert con;
        
        Contract con2 = new Contract();
        con2.SBQQ__Order__c = ord.Id;
        con2.SBQQ__Quote__c = ord.SBQQ__Quote__c;
        con2.SBQQ__Opportunity__c = ord.SBQQ__Quote__r.SBQQ__Opportunity2__c;
        con2.AccountId = ord.AccountId;
        con2.Previous_Contract__c = con.Id;
        insert con2;
        
        con.Status = 'Activated';
        update con;
        System.debug('con --> ' + con);
        /*List<Contract> conList = [SELECT Id, Name FROM Contract WHERE SBQQ__Order__c = :ord.Id];
        System.debug('contList --> ' + conList);
        List<Installation__c> instList = [SELECT Id, Name, Installation_Order_Status__c, Contract__r.SBQQ__Quote__r.SBQQ__Type__c, Order__r.SBQQ__Quote__c, Contract__r.EndDate, Installation_End_Date__c FROM Installation__c];
        ContractTriggerHandler.activate(instList);*/
        Test.stopTest();
    }
    
    @IsTest
    public static void test3()
    {
        Test.startTest();
        Order ord = [SELECT Id, Name, AccountId, SBQQ__Quote__c, SBQQ__Quote__r.SBQQ__Opportunity2__c FROM Order WHERE SBQQ__Quote__c != NULL LIMIT 1];
        ord.Status = 'Activated';
        //ord.SBQQ__Contracted__c = TRUE;
        //update ord;
        ActivateOrderController.activateOrder(ord.Id, Date.today());
        SBQQ__Quote__c qt = [SELECT Id, Name, SBQQ__Type__c FROM SBQQ__Quote__c WHERE Id = :ord.SBQQ__Quote__c];
        qt.SBQQ__Type__c = 'Renewal';
        update qt;
        
        Contract con = new Contract();
        con.SBQQ__Order__c = ord.Id;
        con.SBQQ__Quote__c = ord.SBQQ__Quote__c;
        con.SBQQ__Opportunity__c = ord.SBQQ__Quote__r.SBQQ__Opportunity2__c;
        con.StartDate = Date.today();
        con.AccountId = ord.AccountId;
        insert con;
        
        List<Installation__c> instList = [SELECT Id, Name, Quote_Line_Group__c, Installation_Order_Status__c, Contract__c, Contract__r.StartDate, Contract__r.SBQQ__Quote__c, Contract__r.SBQQ__Quote__r.SBQQ__Type__c, Order__r.SBQQ__Quote__c, Contract__r.EndDate, Installation_Start_Date__c, Installation_End_Date__c FROM Installation__c];
        System.debug('contId --> ' + instList[0].Contract__c);
        System.debug('SBQQ__Quote__c --> ' + instList[0].Contract__r.SBQQ__Quote__c);
        
        for(Installation__c inst : instList)
        {
            Installation_Line__c instLine = (Installation_Line__c)TestDataFactory.createSObject('Installation_Line__c', new Map<String, Object>{
                'Installation__c' => inst.Id,
                    'Net_Total__c' => 100.00,
                    'Start_Date__c' => Date.today(),
                    'End_Date__c' => Date.today()
                    });
        }
        
        //instList[0].Contract__c = cont.Id;
        
        //ContractTriggerHandler.activate(instList);
        List<SBQQ__Subscription__c> subList = [SELECT Id, Name, SBQQ__Product__c, SBQQ__Product__r.Name, SBQQ__QuoteLine__c, CurrencyIsoCode, SBQQ__NetPrice__c,SBQQ__StartDate__c, SBQQ__EndDate__c, SBQQ__SegmentStartDate__c, SBQQ__SegmentEndDate__c FROM SBQQ__Subscription__c];
        ActivateInstallationController.createInstallationLines(instList[0], subList, Date.today());
        ActivateInstallationController.activateInstallation(instList[0].Id, Date.today());
        ActivateInstallationController.calculateProratedAmount(100.00, Date.today(), Date.today().addDays(365), Date.today(), Date.today().addDays(365));
        SalesOrderGeneratorService.generateSalesOrders(instList, FALSE);
        SalesOrderGeneratorService.generateBillingPeriods(Date.today(), Date.today().addDays(365), 30, Date.today());
        SalesOrderGeneratorService.getAccuratePeriodEnd(Date.today(), 27);
        SalesOrderGeneratorService.getBillingCycleMonths('test');
        Map<Id, List<SBQQ__Subscription__c>> subsByInstId = new Map<Id, List<SBQQ__Subscription__c>>();
    
        Set<Id> quoteLineGroupIds = new Set<Id>();
        Set<Id> orderIds = new Set<Id>();
        Map<Id, Set<Id>> orderItemToInstallationIds = new Map<Id, Set<Id>>();
    
        for (Installation__c inst : instList ) {
            if (inst.Quote_Line_Group__c != null) quoteLineGroupIds.add(inst.Quote_Line_Group__c);
            if (inst.Order__c != null) orderIds.add(inst.Order__c);
        }
    
        List<OrderItem> orderItems = [
            SELECT Id, Quote_Line_Group_ID__c, OrderId
            FROM OrderItem
            WHERE Quote_Line_Group_ID__c IN :quoteLineGroupIds
              AND OrderId IN :orderIds
        ];
    
        List<SBQQ__Subscription__c> subs = [
            SELECT Id, Name, SBQQ__Product__c, SBQQ__Product__r.Name, SBQQ__NetPrice__c,SBQQ__StartDate__c, SBQQ__EndDate__c,
                   SBQQ__SegmentStartDate__c, SBQQ__SegmentEndDate__c, CurrencyIsoCode,
                   SBQQ__OrderProduct__c, SBQQ__QuoteLine__c
            FROM SBQQ__Subscription__c
        ];
        for(SBQQ__Subscription__c sub : subs)
        {
            sub.SBQQ__OrderProduct__c = orderItems[0].Id;
        }
        update subs;
        System.debug('subs --> ' + subs);
        InstallationsRenewalService.processRenewalInstallations(instList);
        Test.stopTest();
    }
}