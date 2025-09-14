@isTest
public class ConvertToOpportunityControllerTest {
    
    public static void TestData(String expectedBusinessUnit, String productGroup) {
        // Create default settings
        Default_Account_Owner_Settings__c setting = new Default_Account_Owner_Settings__c();
        setting.SetupOwnerId = UserInfo.getOrganizationId();
        setting.Name = 'EMEA Default Owner ID';
        setting.EMEA_Default_Owner_ID__c = UserInfo.getUserId(); // Use current user
        insert setting;
        
        // Create country mapping
        Country_Mapping__c cm = new Country_Mapping__c();
        cm.Name = 'Test';
        cm.Sales_Region__c = 'Americas';
        insert cm;
        
        // Create test account
        Account acc = new Account();
        acc.Name = 'Test';
        acc.Account_Status__c = 'Unverified';
        acc.AccountSource = 'Cross Department Referral';
        acc.Address1__c = 'Test';
        acc.Town_City__c = 'Texas';
        acc.Country__c = cm.Id;
        acc.Account_Segmentation__c = 'Unknown';
        acc.Customer_Type__c = 'Charity';
        insert acc;
        
        // Create test contact
        Contact con = new Contact();
        con.LastName = 'Test con';
        con.AccountId = acc.Id;
        con.Job_Role__c = 'Crew / Seafarer';
        insert con;
        
        // Create test campaign
        Campaign camp = new Campaign(
            Name = 'Test Campaign',
            IsActive = true
        );
        insert camp;
        
        // Create test lead - set the fields that the Business_Units__c formula depends on
        Lead lead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Company = 'Test Company',
            Account__c = acc.Id,
            Contact__c = con.Id,
            Campaign__c = camp.Id,
            Description = 'Test Lead for Opportunity',
            Products__c = productGroup,
            LeadSource = 'Web'
        );
        insert lead;
        
        Lead updatedLead = [SELECT Id, Business_Units__c FROM Lead WHERE Id = :lead.Id];
        System.debug('Calculated Business Unit: ' + updatedLead.Business_Units__c);
    }
    
    @isTest
    public static void fleetConvertToOpportunity() {
        TestData('Technical Ship Management', 'Fleet Management System (TM Master)');
        
        Lead testLead = [SELECT Id, Business_Units__c FROM Lead WHERE Company = 'Test Company' LIMIT 1];
        System.debug('Test Lead Business Unit: ' + testLead.Business_Units__c);
        
        Test.startTest();
        String opportunityId = ConvertToOpportunityController.convertToOpportunity(testLead.Id);
        Test.stopTest();
        
        
    }
    
    @isTest
    public static void crewConvertToOpportunity() {
        TestData('HCM Crew', 'Crew Management/HR System (Compas)');
        
        Lead testLead = [SELECT Id FROM Lead WHERE Company = 'Test Company' LIMIT 1];
        
        Test.startTest();
        String opportunityId = ConvertToOpportunityController.convertToOpportunity(testLead.Id);
        Test.stopTest();
        
        
    }
    
    @isTest
    public static void marineConvertToOpportunity() {
        TestData('Governance, Risk & Compliance', 'Marine Regulations');
        
        Lead testLead = [SELECT Id FROM Lead WHERE Company = 'Test Company' LIMIT 1];
        
        Test.startTest();
        String opportunityId = ConvertToOpportunityController.convertToOpportunity(testLead.Id);
        Test.stopTest();
        
        
    }
    
    @isTest
    public static void testErrorHandling() {
        // Create lead without account and contact (should fail)
        Lead lead = new Lead(
            FirstName = 'Test',
            LastName = 'Error',
            Company = 'Test Error Company'
        );
        insert lead;
        
        Test.startTest();
        String result = ConvertToOpportunityController.convertToOpportunity(lead.Id);
        Test.stopTest();
        
        System.assertEquals('Error: Missing Account or Contact reference. Account: null, Contact: null', result, 
                            'Should return error for missing account and contact');
    }
    
    @isTest
    public static void testNullBusinessUnit() {
        TestData(null, null); // No business unit
        
        Lead testLead = [SELECT Id FROM Lead WHERE Company = 'Test Company' LIMIT 1];
        
        Test.startTest();
        String opportunityId = ConvertToOpportunityController.convertToOpportunity(testLead.Id);
        Test.stopTest();
        
        Opportunity createdOpp = [SELECT Id, Product_Group__c, Business_Unit__c FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
        
        System.assertNotEquals(null, createdOpp, 'Opportunity should still be created');
        System.assertEquals(null, createdOpp.Product_Group__c, 'Product Group should be null when Business Unit is null');
        System.assertEquals(null, createdOpp.Business_Unit__c, 'Business Unit should be null when not specified');
    }
    
    @isTest
    static void testGetActivatedContracts() {
        TestData('Technical Ship Management', 'Fleet Management System (TM Master)');
        
        Lead testLead = [SELECT Id FROM Lead WHERE Company = 'Test Company' LIMIT 1];
        
        String opportunityId = ConvertToOpportunityController.convertToOpportunity(testLead.Id);
        
        Opportunity opp = [SELECT Id, AccountId, Business_Unit__c FROM Opportunity WHERE Id = :opportunityId];
        
        Contract cont = new Contract(
            AccountId = opp.AccountId,
            Business_Unit__c = 'Technical Ship Management',
            ContractTerm = 12,
            Status = 'Draft',
            StartDate = Date.today()
            
        );
        insert cont;
        
        Test.startTest();
        List<Contract> contracts = ConvertToOpportunityController.getActivatedContracts(opp.Id);                
        opp.Existing_Opportunity_Type__c = 'Up-Sell';
        update opp;
        contracts = ConvertToOpportunityController.getActivatedContracts(opp.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateOpportunityWithContract() {
        TestData('Technical Ship Management', 'Fleet Management System (TM Master)');
        
        Lead testLead = [SELECT Id FROM Lead WHERE Company = 'Test Company' LIMIT 1];
        String opportunityId = ConvertToOpportunityController.convertToOpportunity(testLead.Id);
        
        Opportunity opp = [SELECT Id, AccountId FROM Opportunity WHERE Id = :opportunityId];
        
        Contract cont = new Contract(
            AccountId = opp.AccountId,
            Business_Unit__c = 'Technical Ship Management',
            ContractTerm = 12,
            Status = 'Draft',
            StartDate = Date.today()
        );
        insert cont;
        
        Test.startTest();
        ConvertToOpportunityController.updateOpportunityWithContract(opp.Id, cont.Id);
        Test.stopTest();
        
        Opportunity updatedOpp = [SELECT Amend_Contract_Sales__c, Contract_Type__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(cont.Id, updatedOpp.Amend_Contract_Sales__c, 'Contract should be linked to opportunity');
        System.assertEquals('Existing Contract', updatedOpp.Contract_Type__c, 'Contract type should be updated to Existing Contract');
    }
    
    @isTest
    static void testUpdateOpportunityWithContractException() {
        try {
            Test.startTest();
            ConvertToOpportunityController.updateOpportunityWithContract('invalidId', 'invalidContractId');
            Test.stopTest();
            System.assert(false, 'Should have thrown an exception');
        } catch (Exception e) {
            
        }
    }
    
    @isTest
    static void testGetActivatedContractsException() {
        try {
            Test.startTest();
            ConvertToOpportunityController.getActivatedContracts('invalidId');
            Test.stopTest();
            System.assert(false, 'Should have thrown an exception');
        } catch (Exception e) {
            
        }
    }
}