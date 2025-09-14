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
            Business_Unit__c = 'Technical Ship Management',
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
        
        SBQQ__QuoteLine__c sbql = (SBQQ__QuoteLine__c)TestDataFactory.createSObject('SBQQ__QuoteLine__c', new Map<String, Object>{
            'SBQQ__Quote__c' => qt.Id,
                'SBQQ__Product__c' => prd.Id,
                'SBQQ__Group__c' => sbqlg.Id,
                'SBQQ__PricebookEntryId__c' => pbe.Id
                });
    }
    
    @IsTest
    public static void testUpdateOpportunityStageForActivatedAmendment() {
        SBQQ__Quote__c qt = [SELECT Id,Auto_Termination__c,Auto_Installation__c, SBQQ__Opportunity2__c FROM SBQQ__Quote__c LIMIT 1];
        qt.Auto_Installation__c = True;
        update qt;
        Opportunity opp = [SELECT Id, StageName FROM Opportunity WHERE Id = :qt.SBQQ__Opportunity2__c];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :prod.Id LIMIT 1];
        
        // Create test order
        Order testOrder = new Order(
            SBQQ__Quote__c = qt.Id,
            OpportunityId = opp.Id,
            Status = 'Draft',
            Type = 'Amendment', // Must be Amendment to trigger the logic
            EffectiveDate = Date.today(),
            Pricebook2Id = Test.getStandardPriceBookId()
        );
        insert testOrder;
        
        // Add order product
        OrderItem oi = new OrderItem(
            OrderId = testOrder.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );
        insert oi;
        
        Test.startTest();
        // Activate the order
        testOrder.Status = 'Activated';
        testOrder.Is_Activated__c = true;
        update testOrder;
        Test.stopTest();
        
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
            
            Order ord = (Order)TestDataFactory.createSObject('Order', new Map<String, Object>{
                'SBQQ__Quote__c' => qt.id
                    });
        }
        catch(Exception ex)
        {
            System.debug('ex --> ' + ex);
            System.debug('ex Line --> ' + ex.getLineNumber());
        }
    }
    
    @IsTest
    public static void testGetOpportunityId() {
        
        SBQQ__Quote__c qt = [SELECT Id, SBQQ__Opportunity2__c FROM SBQQ__Quote__c LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Id = :qt.SBQQ__Opportunity2__c];
        
        Order testOrder = new Order(
            SBQQ__Quote__c = qt.Id,
            OpportunityId = opp.Id,
            Status = 'Draft',
            Type = 'Amendment', 
            EffectiveDate = Date.today(),
            Pricebook2Id = Test.getStandardPriceBookId()
        );
        insert testOrder;
        
        Test.startTest();
        
        Map<String, Object> result = OrderTriggerHandler.getOpportunityId(testOrder.Id);
        Test.stopTest();
        
        System.assertEquals(opp.Id, (Id)result.get('opportunityId'), 'Opportunity Id should match');
        System.assertEquals('Amendment', (String)result.get('orderType'), 'Order Type should match');
    }
    
    @IsTest
    static void testUpdateOrderAsAdmin() {
        
        SBQQ__Quote__c qt = [SELECT Id, SBQQ__Opportunity2__c FROM SBQQ__Quote__c LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Id = :qt.SBQQ__Opportunity2__c];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :prod.Id LIMIT 1];
        
        Order ord = new Order(
            SBQQ__Quote__c = qt.Id,
            OpportunityId  = opp.Id,
            Status         = 'Draft',
            Type           = 'Service Delivery',
            EffectiveDate  = Date.today(),
            Pricebook2Id   = Test.getStandardPriceBookId(),
            Installations_Invoiced_Count_Sub__c = 1,
            Installations_Invoiced_Count_Services__c = 1,
            Installations_Invoiced_Value_Sub__c = 1,
            Installations_Invoiced_Value_Services__c = 1,
            Monday_com_URL__c = 'monday.com'
        );
        insert ord;
        
        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );
        insert oi;
        
        Test.startTest();
        OrderTriggerHandler.updateOrderAsAdmin(ord.Id, 'Activated');
        Test.stopTest();
    }
    
    @IsTest
    static void testUpdateSubscriptionOrderFromOpportunity() {
       
        SBQQ__Quote__c qt = [SELECT Id, SBQQ__Opportunity2__c FROM SBQQ__Quote__c LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Id = :qt.SBQQ__Opportunity2__c];
        
       
        Order latestOrd = new Order(
            SBQQ__Quote__c = qt.Id,
            OpportunityId  = opp.Id,
            Status         = 'Draft',
            Type           = 'New',
            EffectiveDate  = Date.today(),
            Pricebook2Id   = Test.getStandardPriceBookId()
        );
        insert latestOrd;
        
        Order serviceOrd = new Order(
            SBQQ__Quote__c = qt.Id,
            OpportunityId  = opp.Id,
            Status         = 'Draft',
            Type           = 'Service Delivery',
            EffectiveDate  = Date.today(),
            Pricebook2Id   = Test.getStandardPriceBookId()
        );
        insert serviceOrd;
        
        Test.startTest();
        OrderTriggerHandler.updateSubscriptionOrderFromOpportunity(new List<Order>{ serviceOrd, latestOrd });
        Test.stopTest();
        
        Order updatedServiceOrd = [SELECT Id, Subscription_Order__c FROM Order WHERE Id = :serviceOrd.Id];
        System.assertEquals(latestOrd.Id, updatedServiceOrd.Subscription_Order__c, 'Service Delivery order should be linked to the latest related order');
    }
}