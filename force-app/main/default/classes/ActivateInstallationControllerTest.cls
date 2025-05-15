@isTest
public class ActivateInstallationControllerTest {

    @TestSetUp
    public static void createData()
    {
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
                'Quote_Line_Group__c' => sbqlg.Id,
            'Vessel_Name__c' => ves1.id,
                'Quote__c' => qt.Id,
                'Installation_Type__c' => 'Vessel'
        });
        Installation__c inst2 = (Installation__c)TestDataFactory.createSObject('Installation__c', new Map<String, Object>{
            'Contract_Customer__c' => acc.Id,
            'Package__c' => packList[1].id,
                'Quote_Line_Group__c' => sbqlg.Id,
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
        Order ord = [SELECT Id, Name FROM Order WHERE SBQQ__Quote__c = :qt.Id];
        ord.Status = 'Activated';
        ord.Is_Activated__c = TRUE;
        ord.SBQQ__Contracted__c = TRUE;
        update ord;

        // Create Contract linked to Quote and Order
        Contract con1 = new Contract(
            AccountId = acc.Id,
            SBQQ__Quote__c = qt.Id,
            SBQQ__Order__c = ord.Id,
            StartDate = Date.today(),
            EndDate = Date.today().addMonths(12),
            ContractTerm = 12,
            Billing_Frequency__c = 'Annual',
            Status = 'Draft'
        );
        insert con1;

        // Update Installations to link to Contract
        inst1.Contract__c = con1.Id;
        inst1.Order__c = ord.Id;
        inst2.Contract__c = con1.Id;
        inst2.Order__c = ord.Id;
        update new List<Installation__c>{inst1, inst2};

        
        
    }

    @isTest
    static void testActivateInstallation() {
        // Arrange
        Test.startTest();
        Contract con = [SELECT Id, Name, SBQQ__Quote__c FROM Contract ORDER BY CreatedDate DESC LIMIT 1];

        Installation__c testInstallation = [
                                                SELECT Id, Contract__r.StartDate, Quote_Line_Group__c, Order__c, Package__c
                                                FROM Installation__c
                                                WHERE Installation_Order_Status__c != 'Active' AND Contract__c = :con.Id
                                                ORDER BY CreatedDate DESC
                                                LIMIT 1
                                            ];
        
        List<OrderItem> orderItems = [
            SELECT Id FROM OrderItem
            WHERE Quote_Line_Group_ID__c = :testInstallation.Quote_Line_Group__c AND OrderId = :testInstallation.Order__c
        ];
        
        List<SBQQ__Subscription__c> subList = [SELECT Id, Name FROM SBQQ__Subscription__c];

        for (SBQQ__Subscription__c sub : subList)
        {
            sub.SBQQ__OrderProduct__c = orderItems[0].Id;
        }
        update subList;

        // Update Installations to link to Contract
        //testInstallation.Contract__c = con.Id;
        // update new List<Installation__c>{testInstallation};

        Date startDate = testInstallation.Contract__r.StartDate;

        // Act
        String result = ActivateInstallationController.activateInstallation(testInstallation.Id, startDate);

        // Assert
        System.assertEquals('SUCCESS', result, 'Installation should activate successfully.');

        // Verify the Installation Lines were created
        List<Installation_Line__c> instLines = [
            SELECT Id, Installation__c, Start_Date__c, End_Date__c
            FROM Installation_Line__c
            WHERE Installation__c = :testInstallation.Id
        ];
        System.assert(!instLines.isEmpty(), 'Installation Lines should be created');

        // Verify the Installation is now marked Active
        testInstallation = [SELECT Installation_Order_Status__c FROM Installation__c WHERE Id = :testInstallation.Id];
        System.assertEquals('Active', testInstallation.Installation_Order_Status__c, 'Installation should be marked Active');

        // Verify Sales Orders were generated
        List<Sales_Order__c> salesOrders = [
            SELECT Id, Installation__c
            FROM Sales_Order__c
            WHERE Installation__c = :testInstallation.Id
        ];
        System.assert(!salesOrders.isEmpty(), 'Sales Orders should be created');

        Test.stopTest();
    }
}