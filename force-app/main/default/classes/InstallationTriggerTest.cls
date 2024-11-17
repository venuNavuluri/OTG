@IsTest
public class InstallationTriggerTest
{
    @TestSetUp
    public static void createTestData()
    {
        /*Default_Account_Owner_Settings__c dao = new Default_Account_Owner_Settings__c();
        dao.EMEA_Default_Owner_ID__c = u.Id;
        insert dao;*/
        
        Profile prof = [SELECT Id FROM Profile WHERE Name='OTG Sales User'];
        User u = (User)TestDataFactory.createSObject('User', new Map<String, Object>{
            'profileId' => prof.id,
            'Username' => 'test@rrrr.com..otguatProd4'
        });
        
        Default_Account_Owner_Settings__c da = (Default_Account_Owner_Settings__c)TestDataFactory.createSObject('Default_Account_Owner_Settings__c', new Map<String, Object>{
            'EMEA_Default_Owner_ID__c' => u.id
        });
        
        Vessel__c vessel = new Vessel__c();
        vessel.Vessel_IMO__c = '1234567';
        vessel.Vessel_MMSI__c = '123456789';
        vessel.Vessel_IMO_Status__c = 'N/A IMO';
        vessel.OTG_Vessel_Type__c = 'Test';
        insert vessel;
        
        Country_Mapping__c countryMap = new Country_Mapping__c();
        countryMap.Name = 'Test';
        countryMap.Sales_Region__c = 'Americas';
        insert countryMap;
        
        Account acc = new Account();
        acc.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('B2B Account').getRecordTypeId();
        acc.Name = 'Test';
        acc.Account_Status__c = 'CRM Verified';
        acc.AccountSource = 'Customer Referral';
        acc.Address1__c = 'Test';
        acc.Town_City__c = 'Test';
        acc.Country__c = countryMap.Id;
        
        Account acc1 = new Account();
        acc1.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('B2B Account').getRecordTypeId();
        acc1.Name = 'Test';
        acc1.Account_Status__c = 'CRM Verified';
        acc1.AccountSource = 'Customer Referral';
        acc1.Address1__c = 'Test';
        acc1.Town_City__c = 'Test';
        acc1.Country__c = countryMap.Id;
        
        insert new List<Account>{acc, acc1};
        
        Installation__c instVsl = new Installation__c();
        instVsl.Contract_Customer__c = acc.Id;
        instVsl.Installation_Type__c = 'Vessel';
        instVsl.Vessel_Name__c = vessel.Id;
        instVsl.Installation_Order_Status__c = 'Active';
        
        Installation__c instOrg = new Installation__c();
        instOrg.Contract_Customer__c = acc.Id;
        instOrg.Installation_Type__c = 'Organisation';
        instOrg.Organisation_Name__c = acc1.Id;
        instOrg.Installation_Order_Status__c = 'Active';
        insert new List<Installation__c>{instVsl, instOrg};
    }
    
    @IsTest
    public static void test()
    {
        Vessel__c vessel = [SELECT Id, Name FROM Vessel__c LIMIT 1];
        List<Account> accList = [SELECT Id, Name FROM Account LIMIT 2];
        Installation__c instVsl = new Installation__c();
        instVsl.Contract_Customer__c = accList[0].Id;
        instVsl.Installation_Type__c = 'Vessel';
        instVsl.Vessel_Name__c = vessel.Id;
        instVsl.Installation_Order_Status__c = 'Active';
        
        Installation__c instOrg = new Installation__c();
        instOrg.Contract_Customer__c = accList[0].Id;
        instOrg.Installation_Type__c = 'Organisation';
        instOrg.Organisation_Name__c = accList[1].Id;
        instOrg.Installation_Order_Status__c = 'Active';
        
        try
        {
            insert new List<Installation__c>{instVsl, instOrg};
        }
        catch(Exception ex)
        {
            System.debug('ex --> ' + ex);
        }
    }
}