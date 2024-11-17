@IsTest
public class CreateBulkInstRecordsControllerTest
{
    @testSetup
    static void setupTestData()
    {
        
        Profile prof = [SELECT Id FROM Profile WHERE Name='OTG Sales User'];
        User u = (User)TestDataFactory.createSObject('User', new Map<String, Object>{
            'profileId' => prof.id,
            'Username' => 'test@rrrr.com.otguatProd1'
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
        });* /

        SBQQ__Subscription__c sub = (SBQQ__Subscription__c)TestDataFactory.createSObject('SBQQ__Subscription__c', new Map<String, Object>{
            'Package__c' => pack.id
            //'SBQQ__Product__c' => prod.id
        });*/
    }
    
    @IsTest
    public static void test1()
    {
        SBQQ__QuoteLineGroup__c qlg = [SELECT Id, Name, SBQQ__Quote__c FROM SBQQ__QuoteLineGroup__c LIMIT 1];
        List<CreateBulkInstallationRecordsController.InstallationWrapper> instWrapList = CreateBulkInstallationRecordsController.createRecords(qlg.SBQQ__Quote__c, qlg.Id, 1, NULL, NULL, NULL);
        CreateBulkInstallationRecordsController.getExistingInstallationRecords(qlg.Id);
        CreateBulkInstallationRecordsController.validateCount(qlg.Id, 5);
        String instWrapListStr = JSON.serialize(instWrapList);
        Vessel__c ves = [SELECT Id, Name FROM Vessel__c LIMIT 1];
        CreateBulkInstallationRecordsController.updateInstallationRecords(instWrapListStr, instWrapListStr, 'Vessel', ves.Id, NULL, NULL, NULL, NULL);
    }
}