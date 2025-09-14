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
        
        Default_Account_Owner_Settings__c setting = new Default_Account_Owner_Settings__c();
        setting.SetupOwnerId=UserInfo.getOrganizationId();
        setting.Name = 'EMEA Default Owner ID';
        setting.EMEA_Default_Owner_ID__c     = '005Si0000004LInIAM';
        insert setting;
        
        Account acc = new Account();
        acc.Name = 'Test Account';
        acc.Customer_Status__c = 'Prospect';
        
        insert acc; 
        
        Product_Solutions__c ps = new Product_Solutions__c();
        ps.Account_ID__c = acc.Id;
        ps.Product_Area_Status__c = 'Prospect';
        ps.Product_Solution__c = 'Technical Ship Management';
            
        insert ps;    
    }
    
    @isTest
    static void OppNameInsertUpdateTest()
    {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Product_Solutions__c ps =[SELECT Id, Product_Area_Status__c, Product_Solution__c FROM Product_Solutions__c LIMIT 1];
        
        Opportunity opp = new Opportunity();
        opp.AccountId = acc.Id;
        opp.CloseDate = Date.today();
        opp.StageName = 'Prospecting & Qualifying';
        opp.Business_Unit__c = 'Technical Ship Management';
        opp.LeadSource  = 'Other';
        opp.Existing_Opportunity_Type__c = 'Whitespace';
        opp.Product_Solutions__c = ps.Id;
        opp.Account_Customer_Status__c = ps.Product_Area_Status__c;
        insert opp;
        
        Opportunity oppResult = [SELECT Id, Name FROM Opportunity LIMIT 1];
        
        System.assertEquals(oppResult.Name, 'TSM/ New Customer/ Whitespace/ Test Account/ ' + Datetime.now().format('yyyy-MM-dd'));
        
        acc.Customer_Status__c = 'Active';
        update acc;
        
        oppResult = [SELECT Id, Name FROM Opportunity LIMIT 1];
        
        System.assertEquals(oppResult.Name, 'TSM/ New Customer/ Cross-sell/ Test Account/ ' + Datetime.now().format('yyyy-MM-dd'));
        
        opp.Existing_Opportunity_Type__c = 'OLP Transition';
        update opp;
        
        oppResult = [SELECT Id, Name FROM Opportunity LIMIT 1];
        
        System.assertEquals(oppResult.Name, 'TSM/ New Customer/ OLP Transition/ Test Account/ ' + Datetime.now().format('yyyy-MM-dd'));
        
    }
    
    @IsTest
    static void testHandleBeforeUpdate_ApprovalStatusNullWhenMovingBackFromProposalReview() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Proposal Review',
            CloseDate = System.today().addDays(30),
            AccountId = acc.Id,
            Approval_Status__c = 'Approved'
        );
        insert opp;
        
        Test.startTest();
        opp.StageName = 'Value Proposition';
        update opp;
        Test.stopTest();
        
        Opportunity updatedOpp = [SELECT Approval_Status__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(null, updatedOpp.Approval_Status__c, 'Approval Status should be null when moving back from Proposal Review');

    }
    
    @isTest
    static void testUpdateAmendContractMethod() {
        // Step 1: Create Account
        Account acc = new Account(Name = 'Amend Test Account');
        insert acc;
    
        // Step 2: Create Contract with Subscription Value and Currency
        Contract con = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today(),
            ContractTerm = 12,
            Business_Unit__c = 'Technical Ship Management',
            Subscription_Value__c = 5000,
            CurrencyIsoCode = 'USD'
        );
        insert con;
        
       con.Status = 'Activated';
       update con;
    
        // Step 3: Insert Opportunity WITHOUT the lookup field
        Opportunity opp = new Opportunity(
            Name = 'Amendment Test Opp',
            AccountId = acc.Id,
            Business_Unit__c = 'Technical Ship Management',
            StageName = 'Prospecting',
            Existing_Opportunity_Type__c = 'Up-sell',
            CloseDate = Date.today().addDays(30),
            Amend_Contract_Sales__c = null,
            CurrencyIsoCode = 'USD'
        );
        insert opp;
    
        // Step 4: Simulate BEFORE UPDATE by setting the lookup field
        Opportunity oppBefore = opp.clone(false, false, false, false);
        opp.Amend_Contract_Sales__c = con.Id;
    
        List<Opportunity> newOppList = new List<Opportunity>{ opp };
        Map<Id, Opportunity> oldOppMap = new Map<Id, Opportunity>{ opp.Id => oppBefore };
    
        Test.startTest();
        UpdateContractAmended.updateAmendContract(newOppList, oldOppMap);
        Test.stopTest();
    
        // Step 5: Assert changes (in-memory only, not committed)
        System.assertEquals(con.Id, opp.SBQQ__AmendedContract__c, 'AmendedContract field should be set');
        System.assertEquals(con.Subscription_Value__c, opp.Account_Subscription_Annual_Order_Value__c, 'Annual Order Value should be copied');
        System.assertEquals(con.CurrencyIsoCode, opp.CurrencyIsoCode, 'Currency should match contract currency');
    }
}