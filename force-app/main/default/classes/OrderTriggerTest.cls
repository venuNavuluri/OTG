@IsTest
public class OrderTriggerTest
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
            'SBQQ__PricebookId__c' => Test.getStandardPriceBookId(),
                'SBQQ__StartDate__c' => Date.today()
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
    }
    
    @IsTest
    public static void testOrder()
    {
        SBQQ__Quote__c qt = [SELECT Id, Name FROM SBQQ__Quote__c LIMIT 1];
        qt.SBQQ__Status__c = 'Approved';
        update qt;
        List<Package__c> packList = [SELECT Id, Name, Installation_Quantity__c FROM Package__c WHERE Quote__c = :qt.Id];
        packList[0].Installation_Quantity__c = 1;
        packList[1].Installation_Quantity__c = 1;
        update packList;
        System.debug('size package --> ' + packList.size());
        Vessel__c ves1 = (Vessel__c)TestDataFactory.createSObject('Vessel__c', new Map<String, Object>{
            'Name' => 'Test1',
                'Vessel_IMO__c' => '123'
        });
        Vessel__c ves2 = (Vessel__c)TestDataFactory.createSObject('Vessel__c', new Map<String, Object>{
            'Name' => 'Test2',
                'Vessel_IMO__c' => '1234'
        });
        try
        {
        Installation__c inst1 = (Installation__c)TestDataFactory.createSObject('Installation__c', new Map<String, Object>{
            'Package__c' => packList[0].id,
            'Vessel_Name__c' => ves1.id,
                'Quote__c' => qt.Id,
                'Installation_Order_Status__c' => 'Draft'
        });
        System.debug('inst1 --> ' + inst1);
        //inst1.Installation_Order_Status__c = 'Active';
        //update inst1;
        System.debug('inst1 --> ' + inst1);
            Installation__c inst2 = (Installation__c)TestDataFactory.createSObject('Installation__c', new Map<String, Object>{
                'Package__c' => packList[1].id,
                    'Vessel_Name__c' => ves2.id,
                    'Quote__c' => qt.Id,
                'Installation_Order_Status__c' => 'Draft'
                    });
            //inst2.Installation_Order_Status__c = 'Active';
            //update inst2;
        }
        catch(Exception ex)
        {
            System.debug('ex --> ' + ex);
            System.debug('ex Line --> ' + ex.getLineNumber());
        }
        Order ord = (Order)TestDataFactory.createSObject('Order', new Map<String, Object>{
            'SBQQ__Quote__c' => qt.Id
        });
        OrderTriggerHandler.updateOrderEndDate(new List<Order>{ord});
    }
    
    @IsTest
    public static void testOrderValidation()
    {
        SBQQ__Quote__c qt = [SELECT Id, Name FROM SBQQ__Quote__c LIMIT 1];
        qt.SBQQ__Status__c = 'Approved';
        update qt;
        List<Package__c> packList = [SELECT Id, Name, Installation_Quantity__c FROM Package__c WHERE Quote__c = :qt.Id];
        packList[0].Installation_Quantity__c = 1;
        packList[1].Installation_Quantity__c = 1;
        update packList;
        System.debug('size package --> ' + packList.size());
        Vessel__c ves1 = (Vessel__c)TestDataFactory.createSObject('Vessel__c', new Map<String, Object>{
            'Name' => 'Test1',
                'Vessel_IMO__c' => '123'
        });
        Vessel__c ves2 = (Vessel__c)TestDataFactory.createSObject('Vessel__c', new Map<String, Object>{
            'Name' => 'Test2',
                'Vessel_IMO__c' => '1234'
        });
        try
        {
            Installation__c inst1 = (Installation__c)TestDataFactory.createSObject('Installation__c', new Map<String, Object>{
                'Package__c' => packList[0].id,
                    'Vessel_Name__c' => ves1.id,
                    'Quote__c' => qt.Id
                    });
            System.debug('inst1 --> ' + inst1);
            //inst1.Installation_Order_Status__c = 'Active';
            //update inst1;
            System.debug('inst1 --> ' + inst1);
            /*Installation__c inst2 = (Installation__c)TestDataFactory.createSObject('Installation__c', new Map<String, Object>{
                'Package__c' => packList[1].id,
                'Vessel_Name__c' => ves2.id,
                'Quote__c' => qt.Id
                });
                inst2.Installation_Order_Status__c = 'Active';
                update inst2;*/
            
            Order ord = (Order)TestDataFactory.createSObject('Order', new Map<String, Object>{
                'SBQQ__Quote__c' => qt.id
                    });
            //OrderTriggerHandler.updateOrderEndDate(new List<Order>{ord});
        }
        catch(Exception ex)
        {
            System.debug('ex --> ' + ex);
            System.debug('ex Line --> ' + ex.getLineNumber());
        }
    }
    
    
    
    /*@IsTest
    public static void test1()
    {
        //Order ord = [SELECT Id, Name FROM Order ORDER BY CreatedDate DESC LIMIT 1];
        SBQQ__Quote__c qt = [SELECT Id, Name, SBQQ__Status__c FROM SBQQ__Quote__c ORDER BY CreatedDate DESC LIMIT 1];
        qt.SBQQ__Status__c = 'Approved';
        update qt;
        List<SBQQ__QuoteLineGroup__c> qlgList = [SELECT Id, Name FROM SBQQ__QuoteLineGroup__c];
        List<Package__c> packList = [SELECT Id, Name, Installation_Quantity__c FROM Package__c WHERE Quote__c = :qt.Id];
        System.debug('qlgList --> ' + qlgList.size());
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
        
        List<SBQQ__QuoteLine__c> qlList = [SELECT Id, Name, SBQQ__Product__c, SBQQ__PriceBookEntryId__c FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c = :qt.Id];
        List<PriceBookEntry> pbeList = [SELECT Id, Product2Id, PriceBook2Id FROM PriceBookEntry WHERE Product2Id = :qlList[0].SBQQ__Product__c];
        System.debug('pbeList --> ' + pbeList);
        qlList[0].SBQQ__PriceBookEntryId__c = [SELECT Id, Product2Id, PriceBook2Id FROM PriceBookEntry WHERE Product2Id = :qlList[0].SBQQ__Product__c].Id;
        update qlList;
        System.debug('qlList --> ' + qlList);
        System.debug('qlList --> ' + qlList.size());
        
        List<Installation__c> instList = [SELECT Id, Name, Package__r.Installation_Quantity__c FROM Installation__c WHERE Quote__c = :qt.Id];
        System.debug('instList --> ' + instList);
        System.debug('int qty 1 --> ' + instList[0].Package__r.Installation_Quantity__c);
        System.debug('int qty 2 --> ' + instList[1].Package__r.Installation_Quantity__c);
        qt.SBQQ__Ordered__c = TRUE;
        try
        {
            qt.Installation__c = inst1.Id;
            System.debug('qt --> ' + qt);
            //update qt;
            Order ord = (Order)TestDataFactory.createSObject('Order', new Map<String, Object>{
            'SBQQ__Quote__c' => qt.Id
        });
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
    }
    
    @IsTest
    public static void test2()
    {
        //Order ord = [SELECT Id, Name FROM Order ORDER BY CreatedDate DESC LIMIT 1];
        SBQQ__Quote__c qt = [SELECT Id, Name, SBQQ__Status__c FROM SBQQ__Quote__c ORDER BY CreatedDate DESC LIMIT 1];
        qt.SBQQ__Status__c = 'Approved';
        update qt;
        List<SBQQ__QuoteLineGroup__c> qlgList = [SELECT Id, Name FROM SBQQ__QuoteLineGroup__c];
        List<Package__c> packList = [SELECT Id, Name, Installation_Quantity__c FROM Package__c WHERE Quote__c = :qt.Id];
        System.debug('qlgList --> ' + qlgList.size());
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
        
        List<SBQQ__QuoteLine__c> qlList = [SELECT Id, Name, SBQQ__Product__c, SBQQ__PriceBookEntryId__c FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c = :qt.Id];
        List<PriceBookEntry> pbeList = [SELECT Id, Product2Id, PriceBook2Id FROM PriceBookEntry WHERE Product2Id = :qlList[0].SBQQ__Product__c];
        System.debug('pbeList --> ' + pbeList);
        qlList[0].SBQQ__PriceBookEntryId__c = [SELECT Id, Product2Id, PriceBook2Id FROM PriceBookEntry WHERE Product2Id = :qlList[0].SBQQ__Product__c].Id;
        update qlList;
        System.debug('qlList --> ' + qlList);
        System.debug('qlList --> ' + qlList.size());
        
        List<Installation__c> instList = [SELECT Id, Name, Package__r.Installation_Quantity__c FROM Installation__c WHERE Quote__c = :qt.Id];
        System.debug('instList --> ' + instList);
        System.debug('int qty 1 --> ' + instList[0].Package__r.Installation_Quantity__c);
        System.debug('int qty 2 --> ' + instList[1].Package__r.Installation_Quantity__c);
        //qt.SBQQ__Ordered__c = TRUE;
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
        Order ord = [SELECT Id, Name FROM Order WHERE SBQQ__Quote__c != NULL];
        
        ActivateOrderController.activateOrder(ord.Id, Date.today());
    }
    
    @IsTest
    public static void test3()
    {
        //Order ord = [SELECT Id, Name FROM Order ORDER BY CreatedDate DESC LIMIT 1];
        SBQQ__Quote__c qt = [SELECT Id, Name, SBQQ__Status__c FROM SBQQ__Quote__c ORDER BY CreatedDate DESC LIMIT 1];
        qt.SBQQ__Status__c = 'Approved';
        update qt;
        List<SBQQ__QuoteLineGroup__c> qlgList = [SELECT Id, Name FROM SBQQ__QuoteLineGroup__c];
        List<Package__c> packList = [SELECT Id, Name, Installation_Quantity__c FROM Package__c WHERE Quote__c = :qt.Id];
        System.debug('qlgList --> ' + qlgList.size());
        System.debug('packList --> ' + packList);
        packList[0].Installation_Quantity__c = 1;
        packList[1].Installation_Quantity__c = 0;
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
        
        List<SBQQ__QuoteLine__c> qlList = [SELECT Id, Name, SBQQ__Product__c, SBQQ__PriceBookEntryId__c FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c = :qt.Id];
        List<PriceBookEntry> pbeList = [SELECT Id, Product2Id, PriceBook2Id FROM PriceBookEntry WHERE Product2Id = :qlList[0].SBQQ__Product__c];
        System.debug('pbeList --> ' + pbeList);
        qlList[0].SBQQ__PriceBookEntryId__c = [SELECT Id, Product2Id, PriceBook2Id FROM PriceBookEntry WHERE Product2Id = :qlList[0].SBQQ__Product__c].Id;
        update qlList;
        System.debug('qlList --> ' + qlList);
        System.debug('qlList --> ' + qlList.size());
        
        List<Installation__c> instList = [SELECT Id, Name, Package__r.Installation_Quantity__c FROM Installation__c WHERE Quote__c = :qt.Id];
        System.debug('instList --> ' + instList);
        System.debug('int qty 1 --> ' + instList[0].Package__r.Installation_Quantity__c);
        System.debug('int qty 2 --> ' + instList[1].Package__r.Installation_Quantity__c);
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
    }*/
}