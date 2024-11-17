@IsTest
public class CustomLookUpControllerTest
{
    @TestSetUp
    public static void testSetUp()
    {
        /*Profile prof = [SELECT Id FROM Profile WHERE Name='OTG Sales User'];
        User u = (User)TestDataFactory.createSObject('User', new Map<String, Object>{
            'profileId' => prof.id,
            'Username' => 'test@rrrr.com'
        });
        
        Contract con = (Contract)TestDataFactory.createSObject('Contract', new Map<String, Object>{
            'Account.ownerid' => u.id
        });*/
        
        Vessel__c ves = (Vessel__c)TestDataFactory.createSObject('Vessel__c', new Map<String, Object>{
            'Name' => 'Test'
        });
    }
    
    @IsTest
    public static void test1()
    {
        CustomLookUpController clc = new CustomLookUpController();
        CustomLookUpController.SearchWrapper sw = new CustomLookUpController.SearchWrapper();
        sw.fieldApiName = 'CurrencyIsoCode';
        sw.otherFieldApiName = 'Name';
        sw.objectApiName = 'Vessel__c';
        sw.searchString = 'Test';
        sw.selectedRecordId = [SELECT Id, Name FROM Vessel__c LIMIT 1].Id;
        
        CustomLookUpController.fetchRecords(sw);
        sw.parentFieldApiName = 'OwnerId';
        sw.parentRecordId = [SELECT Id, Name, OwnerId FROM Vessel__c LIMIT 1].OwnerId;
    }
}