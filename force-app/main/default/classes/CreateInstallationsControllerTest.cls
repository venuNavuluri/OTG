@isTest
public class CreateInstallationsControllerTest {

    @testSetup
    static void setupTestData() {
        
        VRConfiguration__c settings = VRConfiguration__c.getOrgDefaults();
        settings.Opportunity_Validation_Rules__c = TRUE;
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
        //acc.Account_Status__c = 'Active';
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
            //Account_Customer_Status__c = 'Active',
            Sales_Type__c = 'Subscription',
            AccountId = acc.Id,
            CloseDate = Date.today() + 90,
            StageName = 'Prospecting & Qualifying',
            Amount = 1000
        );
        insert opp;

        SBQQ__Quote__c sbq1 = (SBQQ__Quote__c)TestDataFactory.createSObject('SBQQ__Quote__c', new Map<String, Object>{
            'SBQQ__StartDate__c' => Date.today(),
            'SBQQ__Opportunity2__c' => opp.Id
        });
        
         Contract con = (Contract)TestDataFactory.createSObject('Contract', new Map<String, Object>{
            'Account.ownerid' => u.id,
            'SBQQ__Quote__c' => sbq1.Id,
            'SBQQ__Opportunity__c' => opp.Id
        });
        
        Contact cont = (Contact)TestDataFactory.createSObject('Contact', new Map<String, Object>{
            'AccountId' => con.AccountId
        });
        
        SBQQ__Quote__c sbq = (SBQQ__Quote__c)TestDataFactory.createSObject('SBQQ__Quote__c', new Map<String, Object>{
            'SBQQ__MasterContract__c' => con.id,
            'SBQQ__StartDate__c' => Date.today(),
            'SBQQ__Opportunity2__c' => opp.Id
        });
        
        Package__c pack = (Package__c)TestDataFactory.createSObject('Package__c', new Map<String, Object>{
            'Contract__c' => con.id,
            'Quote__c' => sbq.id
        });
        
        SBQQ__QuoteLineGroup__c sbqlg = (SBQQ__QuoteLineGroup__c)TestDataFactory.createSObject('SBQQ__QuoteLineGroup__c', new Map<String, Object>{
            'Package__c' => pack.id,
            'SBQQ__Quote__c' => sbq.id
        });

        Vessel__c ves = (Vessel__c)TestDataFactory.createSObject('Vessel__c');

        Installation__c inst = (Installation__c)TestDataFactory.createSObject('Installation__c', new Map<String, Object>{
            'Contract__c' => con.id,
            'Package__c' => pack.id,
            'Vessel_Name__c' => ves.id
        });

        /*SBQQ__Product__c prod = (SBQQ__Product__c)TestDataFactory.createSObject('SBQQ__Product__c', new Map<String, Object>{
            'Name' => 'Test'
        });*/

        SBQQ__Subscription__c sub = (SBQQ__Subscription__c)TestDataFactory.createSObject('SBQQ__Subscription__c', new Map<String, Object>{
            'Package__c' => pack.id
            //'SBQQ__Product__c' => prod.id
        });
        
        Opportunity opp2 = new Opportunity(
            Name = 'Test',
            LeadSource = 'Cross Department Referral',
            Business_Unit__c = 'Fleet',
            Sales_Type__c = 'Subscription',
            AccountId = acc.Id,
            CloseDate = Date.today() + 90,
            StageName = 'Prospecting & Qualifying',
            SBQQ__AmendedContract__c = con.id,
            Amount = 1000
        );
        insert opp2;

    } 
    
    @isTest
    static void testGetPackages() {
        Contract testContract = [SELECT Id FROM Contract LIMIT 1];

        Test.startTest();
        List<Package__c> packages = CreateInstallationsController.getPackages(testContract.Id);
        Test.stopTest();
        System.assert(packages.size() > 0, 'Packages should be retrieved.');
    }

    @isTest
    static void testCreateInstallationLines() {
        List<SBQQ__Subscription__c> subList = [SELECT Id,Package__c,SBQQ__Product__c,SBQQ__Product__r.Name,SBQQ__StartDate__c,SBQQ__EndDate__c, SBQQ__SegmentStartDate__c, SBQQ__SegmentEndDate__c, SBQQ__NetPrice__c,CurrencyIsoCode FROM SBQQ__Subscription__c LIMIT 1];
        List<Installation__c> instList = [SELECT Id, Name, Package__c FROM Installation__c WHERE Package__c = :subList[0].Package__c];
        List<Id> instIdList = new List<Id>();
        for(Installation__c inst : instList)
        {
            instIdList.add(inst.Id);
        }
        Test.startTest();
        CreateInstallationsController.createInstallationLines(subList, instIdList); 
        Test.stopTest();

        List<Installation_Line__c> instLines = [SELECT Name, Installation__c, Product__c, Start_Date__c, End_Date__c, Net_Total__c, CurrencyIsoCode FROM Installation_Line__c];
        System.assertEquals(1, instLines.size(), 'Expected number of Installation Lines to be created.');
    }
    
    @isTest
    static void testCreateNewInstRecord() {
        Contract testContract = [SELECT Id FROM Contract LIMIT 1];
        Package__c testPackage = [SELECT Id FROM Package__c LIMIT 1];
        Installation__c ins = (Installation__c)TestDataFactory.createSObject('Installation__c', new Map<String, Object>{
            'Contract__c' => testContract.id,
            'Package__c' => testPackage.id
        }, false);
        
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new SBQQMockHttpResponseGenerator());
        String result = CreateInstallationsController.createNewInstRecord(false, testPackage.Id, testContract.Id, ins);
        Test.stopTest();
        
        System.assert(result.startsWith('SUCCESS'), 'The installation record should be created successfully.');
    }
    
    @isTest
    static void testCheckDuplicates() {
        Contract testContract = [SELECT Id FROM Contract LIMIT 1];
        Installation__c testInstallation = [SELECT Id, Vessel_Name__c FROM Installation__c LIMIT 1];
        
        Test.startTest();
        Boolean hasDuplicates = CreateInstallationsController.checkDuplicates(testContract.Id, testInstallation.Vessel_Name__c, null);
        CreateInstallationsController.goToInstallationLineCreation(new List<Id>{testInstallation.Id});
        Test.stopTest();
        
        System.assert(hasDuplicates, 'There should be duplicates found.');
    }

    @isTest
    static void testCheckDuplicates2() {
        Contract testContract = [SELECT Id FROM Contract LIMIT 1];
        Installation__c testInstallation = [SELECT Vessel_Name__c FROM Installation__c LIMIT 1];
        
        Test.startTest();
        Boolean hasDuplicates = CreateInstallationsController.checkDuplicates(testContract.Id, null, null);
        Test.stopTest();
        
        System.assert(hasDuplicates, 'There should be duplicates found.');
    }
    
    @isTest
    static void testTerminateSingleRecord() {
        Installation__c testInstallation = [SELECT Id FROM Installation__c LIMIT 1];
        
        Test.startTest();
        String result = CreateInstallationsController.terminateSingleRecord(testInstallation.Id, Date.today(), 'Test Reason');
        Test.stopTest();
        
        System.assert(result == 'SUCCESS', 'The installation record should be terminated successfully.');
    }
    
    @isTest
    static void testGetInstallations() {
        Contract testContract = [SELECT Id FROM Contract LIMIT 1];
        
        Test.startTest();
        List<CreateInstallationsController.InstallationData> installations = CreateInstallationsController.getInstallations(testContract.Id);
        Test.stopTest();
        
        System.assert(installations.size() > 0, 'Installations should be retrieved.');
    }
    
    @isTest
    static void testGetInstallationRecs() {
        Contract testContract = [SELECT Id FROM Contract LIMIT 1];
        
        Test.startTest();
        List<Installation__c> installations = CreateInstallationsController.getInstallationRecs(testContract.Id);
        Test.stopTest();
        
        System.assert(installations.size() > 0, 'Installation records should be retrieved.');
    }
    
    @IsTest
    public static void testModifyContract()
    {
        Test.startTest();
        try
        {
            List<Installation__c> instList = [SELECT Id, Name, Contract__c, Package__c FROM Installation__c WHERE Contract__c != NULL AND Package__c != NULL];
            CreateInstallationsController.modifyContract(instList[0].Id, Date.today(), instList[0].Contract__c, instList[0].Package__c, FALSE);
            CreateInstallationsController.goToInstallationLineCreation(NULL);
            CreateInstallationsController.createNewInstRecord(FALSE, NULL, NULL, NULL);
            CreateInstallationsController.createInstallationLines(NULL, NULL);
        }
        catch(Exception ex)
        {
            
        }
        Test.stopTEst();
    }
    
    @IsTest
    public static void testNegative()
    {
        try
        {
            CreateInstallationsController.terminateRecords(NULL, Date.today(), '');
        }
        catch(Exception ex)
        {}
    }
    
    @isTest
    static void testGetContractDetails() {
        
        Contract testContract = [SELECT Id FROM Contract LIMIT 1];
    
        // Create Installation with Contract
        Installation__c inst = new Installation__c(
            Contract__c = testContract.Id
        );
        insert inst;
    
        Test.startTest();
        Map<String, Object> details = CreateInstallationsController.getContractDetails(inst.Id);
        Test.stopTest();
   
    }
}