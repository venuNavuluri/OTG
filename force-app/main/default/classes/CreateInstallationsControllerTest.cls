@isTest
public class CreateInstallationsControllerTest {

    @testSetup
    static void setupTestData() {
        
        Profile prof = [SELECT Id FROM Profile WHERE Name='OTG Sales User'];
        User u = (User)TestDataFactory.createSObject('User', new Map<String, Object>{
            'profileId' => prof.id,
            'Username' => 'test@rrr.com'
        });

        Default_Account_Owner_Settings__c da = (Default_Account_Owner_Settings__c)TestDataFactory.createSObject('Default_Account_Owner_Settings__c', new Map<String, Object>{
            'EMEA_Default_Owner_ID__c' => u.id
        });

        Contract con = (Contract)TestDataFactory.createSObject('Contract', new Map<String, Object>{
            'Account.ownerid' => u.id
        });

        SBQQ__Quote__c sbq = (SBQQ__Quote__c)TestDataFactory.createSObject('SBQQ__Quote__c', new Map<String, Object>{
            'SBQQ__MasterContract__c' => con.id
        });

        Package__c pack = (Package__c)TestDataFactory.createSObject('Package__c', new Map<String, Object>{
            'Contract__c' => con.id,
            'Quote__c' => sbq.id
        });

        SBQQ__QuoteLineGroup__c sbqlg = (SBQQ__QuoteLineGroup__c)TestDataFactory.createSObject('SBQQ__QuoteLineGroup__c', new Map<String, Object>{
            'Package__c' => pack.id,
            'SBQQ__Quote__c' => sbq.id
        });

        Contact cont = (Contact)TestDataFactory.createSObject('Contact', new Map<String, Object>{
            'AccountId' => con.AccountId
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
        List<SBQQ__Subscription__c> subList = [SELECT Id,Package__c,SBQQ__Product__c,SBQQ__Product__r.Name,SBQQ__StartDate__c,SBQQ__EndDate__c,SBQQ__NetPrice__c,CurrencyIsoCode FROM SBQQ__Subscription__c LIMIT 1];

        Test.startTest();
        CreateInstallationsController.createInstallationLines(subList);
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
    
    /*@isTest
    static void testCreateRecords() {
        Contract testContract = [SELECT Id FROM Contract LIMIT 1];
        Package__c testPackage = [SELECT Id FROM Package__c LIMIT 1];
        Installation__c testInstallation = new Installation__c(
            Contract__c = testContract.Id,
            Package__c = testPackage.Id
        );
        
        Test.startTest();
        String result = CreateInstallationsController.createRecords(false, testPackage.Id, testContract.Id, testInstallation);
        Test.stopTest();
        
        System.assert(result.startsWith('SUCCESS'), 'Records should be created successfully.');
    }*/
    
    @isTest
    static void testCheckDuplicates() {
        Contract testContract = [SELECT Id FROM Contract LIMIT 1];
        Installation__c testInstallation = [SELECT Vessel_Name__c FROM Installation__c LIMIT 1];
        
        Test.startTest();
        Boolean hasDuplicates = CreateInstallationsController.checkDuplicates(testContract.Id, testInstallation.Vessel_Name__c, null);
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
    
}