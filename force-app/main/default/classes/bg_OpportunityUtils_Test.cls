/*****************************************************************
 * bg_OpportunityUtils_Test
 *
 * Test class for bg_OpportunityUtils 
 * 
 *
 * Author: Ben Riminton
 * Created: 03-09-2021
******************************************************************/

@isTest
global class bg_OpportunityUtils_Test {

    @TestSetup
    static void makeData(){

        Account acc = new Account();
        acc.Name = 'Test Account';
        acc.Customer_Status__c = 'Prospect';

        insert acc;    
    }

    @isTest
    static void OppNameInsertUpdateTest()
    {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = new Opportunity();
        opp.AccountId = acc.Id;
        opp.CloseDate = Date.today();
        opp.StageName = 'Prospecting & Qualifying';
        opp.Business_Unit__c = 'Fleet';
        opp.LeadSource  = 'Other';
        opp.Existing_Opportunity_Type__c = 'Whitespace';
        insert opp;

        Opportunity oppResult = [SELECT Id, Name FROM Opportunity LIMIT 1];

        System.assertEquals(oppResult.Name, 'Fleet/ New Customer/ Whitespace/ Test Account/ ' + Datetime.now().format('yyyy-MM-dd'));

        acc.Customer_Status__c = 'Active';
        update acc;

        oppResult = [SELECT Id, Name FROM Opportunity LIMIT 1];

        System.assertEquals(oppResult.Name, 'Fleet/ New Customer/ Cross-sell/ Test Account/ ' + Datetime.now().format('yyyy-MM-dd'));

        opp.Existing_Opportunity_Type__c = 'OLP Transition';
        update opp;

        oppResult = [SELECT Id, Name FROM Opportunity LIMIT 1];

        System.assertEquals(oppResult.Name, 'Fleet/ New Customer/ OLP Transition/ Test Account/ ' + Datetime.now().format('yyyy-MM-dd'));

    }
}