@isTest
public class ConvertToOpportunityControllerTest {
    @testSetup
    public static void testDataSetup()
    {
        UserRole cfmSalesApac = [select Id, Name from UserRole where Name = 'CFM Sales APAC'];
        UserRole cfmSalesEmeaa = [select Id, Name from UserRole where Name = 'CFM Sales EMEAA'];
        UserRole vpoSales = [select Id, Name from UserRole where Name = 'VPO Sales'];
        UserRole isfwkSales = [select Id, Name from UserRole where Name = 'Watchkeeper Sales Director'];
        UserRole apacSales = [select Id, Name from UserRole where Name = 'Other APAC1 Sales'];
        UserRole emeaSales = [select Id, Name from UserRole where Name = 'EMEA1 Sales'];
        Profile prof = [select Id, Name from Profile where Name = 'Identity User'];
        
        User cfmSalesUserAPAC = new User(FirstName='Test',
                            LastName='User1',
                            Alias='tu1',
                            Email='testuser1@email.com',
                            Username='testuser1@email.com.otg',
                            Division='APAC',
                            UserRoleId = cfmSalesApac.Id,
                            ProfileId = prof.Id,
                            TimeZoneSidKey = 'GMT',
                            LanguageLocaleKey = 'en_US',
                            EmailEncodingKey = 'UTF-8',
                            LocaleSidKey = 'en_US');
        insert cfmSalesUserAPAC;
        
        User cfmSalesUserEMEAA = new User(FirstName='Test',
                            LastName='User2',
                            Alias='tu2',
                            Email='testuser2@email.com',
                            Username='testuser2@email.com.otg',
                            Division='EMEAA',
                            UserRoleId = cfmSalesEmeaa.Id,
                            ProfileId = prof.Id,
                            TimeZoneSidKey = 'GMT',
                            LanguageLocaleKey = 'en_US',
                            EmailEncodingKey = 'UTF-8',
                            LocaleSidKey = 'en_US');
        insert cfmSalesUserEMEAA;
        
        User vpoSalesUser = new User(FirstName='Test',
                            LastName='User3',
                            Alias='tu3',
                            Email='testuser3@email.com',
                            Username='testuser3@email.com.otg',
                            UserRoleId = vpoSales.Id,
                            ProfileId = prof.Id,
                            TimeZoneSidKey = 'GMT',
                            LanguageLocaleKey = 'en_US',
                            EmailEncodingKey = 'UTF-8',
                            LocaleSidKey = 'en_US');
        insert vpoSalesUser;
        
        User isfwkSalesUser = new User(FirstName='Test',
                            LastName='User4',
                            Alias='tu4',
                            Email='testuser4@email.com',
                            Username='testuser4@email.com.otg',
                            UserRoleId = isfwkSales.Id,
                            ProfileId = prof.Id,
                            TimeZoneSidKey = 'GMT',
                            LanguageLocaleKey = 'en_US',
                            EmailEncodingKey = 'UTF-8',
                            LocaleSidKey = 'en_US');
        insert isfwkSalesUser;
        
        User apacSalesUser = new User(FirstName='Test',
                            LastName='User5',
                            Alias='tu5',
                            Email='testuser5@email.com',
                            Username='testuser5@email.com.otg',
                            UserRoleId = apacSales.Id,
                            ProfileId = prof.Id,
                            TimeZoneSidKey = 'GMT',
                            LanguageLocaleKey = 'en_US',
                            EmailEncodingKey = 'UTF-8',
                            LocaleSidKey = 'en_US');
        insert apacSalesUser;
        
        User emeaSalesUser = new User(FirstName='Test',
                            LastName='User6',
                            Alias='tu6',
                            Email='testuser6@email.com',
                            Username='testuser6@email.com.otg',
                            UserRoleId = emeaSales.Id,
                            ProfileId = prof.Id,
                            TimeZoneSidKey = 'GMT',
                            LanguageLocaleKey = 'en_US',
                            EmailEncodingKey = 'UTF-8',
                            LocaleSidKey = 'en_US');
        insert emeaSalesUser;
    }
    
    public static void TestData(String expectedBusinessUnit, String productGroup) {
        // Create default settings
        Default_Account_Owner_Settings__c setting = new Default_Account_Owner_Settings__c();
        setting.SetupOwnerId = UserInfo.getOrganizationId();
        setting.Name = 'EMEA Default Owner ID';
        setting.APAC_Default_Owner_ID__c = UserInfo.getUserId(); // Use current user
        setting.EMEA_Default_Owner_ID__c = UserInfo.getUserId(); // Use current user
        setting.Americas_Default_Owner_ID__c = UserInfo.getUserId(); // Use current user
        insert setting;
        
        User apacSalesUser = [select Id from User where Username = 'testuser5@email.com.otg'];
        User emeaSalesUser = [select Id from User where Username = 'testuser6@email.com.otg'];
        
        // Create country mapping
        Country_Mapping__c cm = new Country_Mapping__c();
        cm.Name = 'Test';
        cm.Sales_Region__c = 'Americas';
        cm.LROO_Product_Acc_Owner__c = apacSalesUser.Id;
        cm.OTG_Product_Acc_Owner__c = emeaSalesUser.Id;
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
    @isTest
    public static void isfwkConvertToOpportunity() {
        TestData('ISF Watchkeeper', 'ISF Watchkeeper');
        
        Lead testLead = [SELECT Id, Business_Units__c, Products__c FROM Lead WHERE Company = 'Test Company' LIMIT 1];
        
        System.debug('Lead Products: ' + testLead.Products__c);
        
        Test.startTest();
        String opportunityId = ConvertToOpportunityController.convertToOpportunity(testLead.Id);
        Test.stopTest();
        
        
    }
    @isTest
    public static void cfmConvertToOpportunity() {
        TestData('Cloud Fleet Manager', 'Cloud Fleet Manager');
        
        Lead testLead = [SELECT Id, Business_Units__c, Products__c FROM Lead WHERE Company = 'Test Company' LIMIT 1];
        
        System.debug('Lead Products: ' + testLead.Products__c);
        
        Test.startTest();
        String opportunityId = ConvertToOpportunityController.convertToOpportunity(testLead.Id);
        Test.stopTest();
        
        
    }
    @isTest
    public static void rmConvertToOpportunity() {
        TestData('Risk Manager', 'Risk Manager');
        
        Lead testLead = [SELECT Id, Business_Units__c, Products__c FROM Lead WHERE Company = 'Test Company' LIMIT 1];
        
        System.debug('Lead Products: ' + testLead.Products__c);
        
        Test.startTest();
        String opportunityId = ConvertToOpportunityController.convertToOpportunity(testLead.Id);
        Test.stopTest();
        
        
    }
    @isTest
    public static void r4sConvertToOpportunity() {
        TestData('Regs4ships', 'Regs4ships');
        
        Lead testLead = [SELECT Id, Business_Units__c, Products__c FROM Lead WHERE Company = 'Test Company' LIMIT 1];
        
        System.debug('Lead Products: ' + testLead.Products__c);
        
        Test.startTest();
        String opportunityId = ConvertToOpportunityController.convertToOpportunity(testLead.Id);
        Test.stopTest();
        
        
    }
}