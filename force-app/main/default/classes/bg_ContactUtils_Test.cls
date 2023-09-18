/*****************************************************************
 * bg_ContactUtils_Test
 *
 * Test class for bg_Contact
 * 
 *
 * Author: Dawid Lominski
 * Created: 21-10-2021
******************************************************************/

@IsTest
global class bg_ContactUtils_Test {

    @TestSetup
    static void makeData(){
        
        Account acc = new Account();
        acc.Name = 'Test Account';
        acc.Customer_Status__c = 'Prospect';

        insert acc;
        
        Contact con = new Contact();
        con.LastName = 'Test';
        con.MobilePhone = '01234567890';
        con.Account = acc;

        insert con;

        Opportunity opp = new Opportunity();
        opp.AccountId = acc.Id;
        opp.CloseDate = Date.today();
        opp.StageName = 'Prospecting & Qualifying';
        opp.Contact_Name__c = con.Id;
        opp.Business_Unit__c = 'Learning & Assessment';
        opp.Product_Group__c ='MTS';
        opp.LeadSource = 'Other';
        insert opp;
    }

    @IsTest
    static void inactiveContactOnOpps_Test_1() {
        Boolean error = false;
        String exceptionType;
        
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        con.Inactive__c = true;

        Test.startTest();
        try {
            update con;
        }
        catch (Exception e) {
            error = true;
            exceptionType = e.getTypeName();
        }
        Test.stopTest();

        System.assertEquals(true, error);
        System.assertEquals('System.DmlException', exceptionType);
    }

    @IsTest
    static void inactiveContactOnClosedOpps_Test_1() {
        Boolean error = false;
        String exceptionType;
        
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        opp.StageName = 'Closed Won';
        opp.Completed_Competitor_Insights__c = true;
        update opp;

        Contact con = [SELECT Id FROM Contact LIMIT 1];
        con.Inactive__c = true;

        Test.startTest();
        try {
            update con;
        }
        catch (Exception e) {
            error = true;
            exceptionType = e.getTypeName();
        }
        Test.stopTest();

        System.assertEquals(false, error);
        System.assertEquals(true, con.Inactive__c);
    }

}