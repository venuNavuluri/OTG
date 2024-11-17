@IsTest
public class CreateOrderFromQuoteControllerTest
{
    @testSetup
    static void setupTestData()
    {
        Profile prof = [SELECT Id FROM Profile WHERE Name='OTG Sales User'];
        User u = (User)TestDataFactory.createSObject('User', new Map<String, Object>{
            'profileId' => prof.id,
            'Username' => 'test@rrrr.com.otguatProd2'
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
                'Pricebook2Id' => Test.getStandardPriceBookId()
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
        
        Package__c pack = (Package__c)TestDataFactory.createSObject('Package__c', new Map<String, Object>{
            //'Contract__c' => con.id,
                'Quote__c' => qt.id,
                'Installation_Quantity__c' => 1
        });
        
        SBQQ__QuoteLineGroup__c sbqlg = (SBQQ__QuoteLineGroup__c)TestDataFactory.createSObject('SBQQ__QuoteLineGroup__c', new Map<String, Object>{
            'Package__c' => pack.id,
                'SBQQ__Quote__c' => qt.id,
                'Installation_Quantity__c' => 1
        });
        
        SBQQ__QuoteLine__c sbql = (SBQQ__QuoteLine__c)TestDataFactory.createSObject('SBQQ__QuoteLine__c', new Map<String, Object>{
            'SBQQ__Quote__c' => qt.Id,
                'SBQQ__Product__c' => prd.Id,
                'SBQQ__Group__c' => sbqlg.Id,
                'SBQQ__PricebookEntryId__c' => pbe.Id
        });
        
        /*Profile prof = [SELECT Id FROM Profile WHERE Name='OTG Sales User'];
        User u = (User)TestDataFactory.createSObject('User', new Map<String, Object>{
            'profileId' => prof.id,
            'Username' => 'test@rrrr.com'
        });

        Default_Account_Owner_Settings__c da = (Default_Account_Owner_Settings__c)TestDataFactory.createSObject('Default_Account_Owner_Settings__c', new Map<String, Object>{
            'EMEA_Default_Owner_ID__c' => u.id
        });

        / *Contract con = (Contract)TestDataFactory.createSObject('Contract', new Map<String, Object>{
            'Account.ownerid' => u.id
        });* /

        SBQQ__Quote__c sbq = (SBQQ__Quote__c)TestDataFactory.createSObject('SBQQ__Quote__c', new Map<String, Object>{
            //'SBQQ__MasterContract__c' => con.id
        });

        Package__c pack = (Package__c)TestDataFactory.createSObject('Package__c', new Map<String, Object>{
            //'Contract__c' => con.id,
                'Quote__c' => sbq.id,
                'Installation_Quantity__c' => 1
        });

        SBQQ__QuoteLineGroup__c sbqlg = (SBQQ__QuoteLineGroup__c)TestDataFactory.createSObject('SBQQ__QuoteLineGroup__c', new Map<String, Object>{
            'Package__c' => pack.id,
                'SBQQ__Quote__c' => sbq.id,
                'Installation_Quantity__c' => 1
        });

        /*Contact cont = (Contact)TestDataFactory.createSObject('Contact', new Map<String, Object>{
            'AccountId' => sbq.SBQQ__Account__c
        });*/

        Vessel__c ves = (Vessel__c)TestDataFactory.createSObject('Vessel__c');

        Installation__c inst = (Installation__c)TestDataFactory.createSObject('Installation__c', new Map<String, Object>{
            //'Contract__c' => sbq.SBQQ__Account__c,
            'Package__c' => pack.id,
            'Vessel_Name__c' => ves.id
        });
    }
    
    @IsTest
    public static void test1()
    {
        try
        {
            SBQQ__QuoteLineGroup__c qlg = [SELECT Id, Name, SBQQ__Quote__c FROM SBQQ__QuoteLineGroup__c WHERE SBQQ__Quote__r.SBQQ__Account__r.Name = 'Test' LIMIT 1];
            System.debug('qlg --> ' + qlg);
            SBQQ__Quote__c qt = new SBQQ__Quote__c();
            CreateOrderFromQuoteController.validateInstallationCount(qlg.SBQQ__Quote__c);
            CreateOrderFromQuoteController.updateQuoteToOrdered(qlg.SBQQ__Quote__c);
        }
        catch(Exception ex)
        {
            System.debug('ex --> ' + ex);
        }
    }
    
    @IsTest
    public static void test2()
    {
        SBQQ__Quote__c qt = [SELECT Id, Name, SBQQ__Type__c, SBQQ__Primary__c, SBQQ__Status__c FROM SBQQ__Quote__c LIMIT 1];
        qt.SBQQ__Status__c = 'Approved';
        update qt;
        /*Package__c pack = [SELECT Id, Name FROM Package__c LIMIT 1];
        List<Installation__c> instList = [SELECT Id, Name FROM Installation__c LIMIT 2];
        UpdatePackageController.fetchPackages(qt.Id);
        UpdatePackageController.getPackageData(pack.Id);
        UpdatePackageController.saveInstallation(pack.Id, instList[0].Id, instList[1].Id);*/
    }
}