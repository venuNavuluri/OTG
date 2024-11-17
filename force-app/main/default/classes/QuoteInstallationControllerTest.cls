@IsTest
public class QuoteInstallationControllerTest
{
    @TestSetup
    static void setupTestData()
    {
        Profile prof = [SELECT Id FROM Profile WHERE Name='OTG Sales User'];
        User u = (User)TestDataFactory.createSObject('User', new Map<String, Object>{
            'profileId' => prof.id,
            'Username' => 'test@rrrr.com..otguatProd3'
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
                'Installation_Quantity__c' => 3
        });
        
        SBQQ__QuoteLine__c sbql = (SBQQ__QuoteLine__c)TestDataFactory.createSObject('SBQQ__QuoteLine__c', new Map<String, Object>{
            'SBQQ__Quote__c' => qt.Id,
                'SBQQ__Product__c' => prd.Id,
                'SBQQ__Group__c' => sbqlg.Id,
                'SBQQ__PricebookEntryId__c' => pbe.Id
        });

        Vessel__c ves1 = (Vessel__c)TestDataFactory.createSObject('Vessel__c', new Map<String, Object>{
            'Name' => 'Test1',
                'Vessel_IMO__c' => '123'
        });
        Vessel__c ves2 = (Vessel__c)TestDataFactory.createSObject('Vessel__c', new Map<String, Object>{
            'Name' => 'Test2',
                'Vessel_IMO__c' => '1234'
        });
        Vessel__c ves3 = (Vessel__c)TestDataFactory.createSObject('Vessel__c', new Map<String, Object>{
            'Name' => 'Test3',
                'Vessel_IMO__c' => '12345'
        });

        Installation__c inst = (Installation__c)TestDataFactory.createSObject('Installation__c', new Map<String, Object>{
            //'Contract__c' => sbq.SBQQ__Account__c,
            'Package__c' => pack.id,
            'Vessel_Name__c' => ves1.id
        });
    }
    
    @IsTest
    public static void test()
    {
        QuoteInstallationController qic = new QuoteInstallationController();
        SBQQ__Quote__c qt = [SELECT Id, Name FROM SBQQ__Quote__c LIMIT 1];
        String st = QuoteInstallationController.fetchQuoteLineGroups(qt.Id);
        List<QuoteInstallationController.QuoteRecordWrapper> qrwList = (List<QuoteInstallationController.QuoteRecordWrapper>)JSON.deSerialize(st, List<QuoteInstallationController.QuoteRecordWrapper>.class);
        QuoteInstallationController.fetchQuoteLineGroupProducts(qrwList[0].qlg.Id);
        List<Vessel__c> vesList = [SELECT Id, Name, Vessel_IMO__c FROM Vessel__c ORDER BY Name];
        Installation__c inst1 = new Installation__c(
            Installation_Type__c = 'Vessel',
            Vessel_Name__c = vesList[0].Id,
            Quote_Line_Group__c = qrwList[0].qlg.Id
        );
        List<Installation__c> instList = new List<Installation__c>();
        instList.add(inst1);
        QuoteInstallationController.saveInstallation(instList);
        Account invAcc = [SELECT Id, Name FROM Account WHERE RecordType.Name = 'Invoice Account'];
        String stCsv = 'VesselIMO,InvoiceAccount\n';
        stCsv += '123,' + invAcc.Id + '\n';
        ContentVersion ContVerFile = new ContentVersion();
        ContVerFile.VersionData = Blob.valueOf(stCsv);
        ContVerFile.Title = 'title'; 
        ContVerFile.ContentLocation= 's';
        ContVerFile.PathOnClient='title.csv';
        insert ContVerFile;
        
        QuoteInstallationController.createInstallations(contVerFile.Id, qt.Id, qrwList[0].qlg.Id);
        QuoteInstallationController.createRecords(qt.Id, qrwList[0].qlg.Id, 1, NULL, invAcc.Id, NULL);
    }
}