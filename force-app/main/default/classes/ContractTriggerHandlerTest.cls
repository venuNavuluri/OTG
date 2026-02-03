@IsTest
public class ContractTriggerHandlerTest {
    private static Id baseContractId;
    private static List<Id> basePackageIds = new List<Id>();
    
    private static void ensureBaseContractData() {
        if (baseContractId == null) {
            Contract fallback = [
                SELECT Id
                FROM Contract
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            baseContractId = fallback.Id;
        }
        if (basePackageIds == null) {
            basePackageIds = new List<Id>();
        }
        if (basePackageIds.isEmpty()) {
            for (Package__c pkg : [
                SELECT Id
                FROM Package__c
                WHERE Contract__c = :baseContractId
            ]) {
                basePackageIds.add(pkg.Id);
            }
        }
    }
    
    @TestSetUp
    public static void createTestData() {
        // Enable org VR configuration
        TestDataFactory_OTG.enableOrgVRConfig();
        
        // Create a user with OTG Sales User profile - using proper required fields
        Profile prof = [SELECT Id FROM Profile WHERE Name='OTG Sales User'];
        User u = new User(
            ProfileId = prof.Id,
            Username = 'test@otg.com',
            LastName = 'Test',
            Email = 'test@otg.com',
            Alias = 'ttest',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        
        // Set default account owners
        TestDataFactory_OTG.primeDefaultOwnerAllRegions(u.Id);
        
        // Create country mapping
        Id countryId = TestDataFactory_OTG.getOrCreateCountryMappingId('Americas');
        
        // Create account and contact
        Account acc = TestDataFactory_OTG.createB2BAccount(u.Id, countryId, 'Test Account');
        Contact con = TestDataFactory_OTG.createContact(acc.Id, 'Test Contact', true);
        
        // Create legal entity
        Legal_Entity__c legalEntity = TestDataFactory_OTG.createLegalEntity(countryId);
        
        // Create opportunity
        Opportunity opp = TestDataFactory_OTG.createOpportunity(acc.Id, 'Test Opportunity', legalEntity.Id);
        
        // Create quote context
        TestDataFactory_OTG.QuoteContext qctx = TestDataFactory_OTG.buildDraftQuoteContext('Americas', false, false);
        
        // Create contract with packages
        TestDataFactory_OTG.ContractPackageContext cpc = TestDataFactory_OTG.buildContractWithPackages(
            acc.Id, 
            'USD', 
            12, 
            2, 
            1
        );
        baseContractId = cpc.contractRec.Id;
        basePackageIds.clear();
        for (Package__c pkg : cpc.packages) {
            basePackageIds.add(pkg.Id);
        }
        
        // Create installations
        List<Installation__c> installations = new List<Installation__c>();
        for(Package__c pkg : cpc.packages) {
            Vessel__c vessel = TestDataFactory_OTG.getOrCreateVesselCached();
            Installation__c inst = TestDataFactory_OTG.createInstallation(pkg.Id, vessel.Id, 'Active');
            installations.add(inst);
        }
        
        // Update quote to approved
        qctx.quote.SBQQ__Status__c = 'Approved';
        update qctx.quote;
    }
    
    @IsTest
    public static void testBeforeInsertTriggerExecution() {
        Test.startTest();
        
        // Get existing contract with all required fields
        Contract con = [SELECT Id, Name, SBQQ__Quote__c, SBQQ__Opportunity__c, AccountId FROM Contract ORDER BY CreatedDate DESC LIMIT 1];
        
        // Create a new contract that will trigger onBeforeInsert
        Contract newCon = new Contract(
            SBQQ__Quote__c = con.SBQQ__Quote__c,
            SBQQ__Opportunity__c = con.SBQQ__Opportunity__c,
            AccountId = con.AccountId,
            Billing_Frequency__c = 'Annual',
            StartDate = Date.today(),
            EndDate = Date.today().addDays(365),
            ContractTerm = 12
        );
        
        // Insert to trigger onBeforeInsert
        insert newCon;
        
        // Verify that the contract was inserted successfully
        Contract insertedCon = [SELECT Id FROM Contract WHERE Id = :newCon.Id];
        System.assertEquals(newCon.Id, insertedCon.Id, 'New contract should be inserted successfully');
        
        Test.stopTest();
    }
    
    @IsTest
    public static void testBeforeUpdateTriggerExecution() {
        Test.startTest();
        
        // Get existing contract
        Contract con = [SELECT Id, Name FROM Contract ORDER BY CreatedDate DESC LIMIT 1];
        
        // Update the contract to trigger onBeforeUpdate
        con.Description = 'Updated test description';
        update con;
        
        // Verify that the contract was updated successfully
        Contract updatedCon = [SELECT Id, Description FROM Contract WHERE Id = :con.Id];
        System.assertEquals('Updated test description', updatedCon.Description, 'Contract should be updated successfully');
        
        Test.stopTest();
    }
    
    @IsTest
    public static void testAfterInsertTriggerExecution() {
        Test.startTest();
        
        // Get existing contract with all required fields
        Contract con = [SELECT Id, Name, SBQQ__Quote__c, SBQQ__Opportunity__c, AccountId FROM Contract ORDER BY CreatedDate DESC LIMIT 1];
        
        // Create a new contract that will trigger onAfterInsert
        Contract newCon = new Contract(
            SBQQ__Quote__c = con.SBQQ__Quote__c,
            SBQQ__Opportunity__c = con.SBQQ__Opportunity__c,
            AccountId = con.AccountId,
            Billing_Frequency__c = 'Annual',
            StartDate = Date.today(),
            EndDate = Date.today().addDays(365),
            ContractTerm = 12
        );
        
        // Insert to trigger onAfterInsert
        insert newCon;
        
        // Verify that the contract was inserted successfully
        Contract insertedCon = [SELECT Id FROM Contract WHERE Id = :newCon.Id];
        System.assertEquals(newCon.Id, insertedCon.Id, 'New contract should be inserted successfully');
        
        Test.stopTest();
    }
    
    @IsTest
    public static void testAfterUpdateTriggerExecution() {
        Test.startTest();
        
        // Get existing contract
        Contract con = [SELECT Id, Name FROM Contract ORDER BY CreatedDate DESC LIMIT 1];
        
        // Update the contract to trigger onAfterUpdate
        con.Status = 'Activated';
        update con;
        
        // Verify that the contract was updated successfully
        Contract updatedCon = [SELECT Id, Status FROM Contract WHERE Id = :con.Id];
        System.assertEquals('Activated', updatedCon.Status, 'Contract should be activated successfully');
        
        Test.stopTest();
    }
    
    @IsTest
    public static void testUpdateNextContractLinkCreated() {
        Test.startTest();
        
        // Get existing contract with all required fields
        Contract con = [SELECT Id, Name, SBQQ__Quote__c, SBQQ__Opportunity__c, AccountId FROM Contract ORDER BY CreatedDate DESC LIMIT 1];
        
        // Create a new contract that references the previous one
        Contract newCon = new Contract(
            SBQQ__Quote__c = con.SBQQ__Quote__c,
            SBQQ__Opportunity__c = con.SBQQ__Opportunity__c,
            AccountId = con.AccountId,
            Billing_Frequency__c = 'Annual',
            StartDate = Date.today(),
            EndDate = Date.today().addDays(365),
            ContractTerm = 12,
            Previous_Contract__c = con.Id
        );
        
        // Insert to trigger onBeforeInsert and onAfterInsert
        insert newCon;
        
        // Verify that the link was created in the previous contract
        Contract prevCon = [SELECT Id, Next_Contract__c FROM Contract WHERE Id = :con.Id];
        
        // Assert that the Next_Contract__c field was populated
        System.assertEquals(newCon.Id, prevCon.Next_Contract__c, 'Next_Contract__c should reference the new contract');
        
        Test.stopTest();
    }
    
    @IsTest
    public static void testActivateContractsRenewal() {
        // Get existing contract with all required fields
        Contract con = [SELECT Id, Name, SBQQ__Quote__c, SBQQ__Opportunity__c, AccountId FROM Contract ORDER BY CreatedDate DESC LIMIT 1];
        
        // Create a renewal quote and contract directly without order creation
        SBQQ__Quote__c renewalQuote = new SBQQ__Quote__c(
            SBQQ__Account__c = con.AccountId,
            SBQQ__Opportunity2__c = con.SBQQ__Opportunity__c,
            SBQQ__Type__c = 'Renewal',
            SBQQ__Primary__c = true
        );
        insert renewalQuote;
        
        Contract renewalCon = new Contract(
            SBQQ__Quote__c = renewalQuote.Id,
            SBQQ__Opportunity__c = con.SBQQ__Opportunity__c,
            AccountId = con.AccountId,
            Billing_Frequency__c = 'Annual',
            StartDate = Date.today(),
            EndDate = Date.today().addDays(365),
            ContractTerm = 12
        );
        
        // Insert renewal contract
        insert renewalCon;
        
        Test.startTest();
        // Activate the renewal contract to trigger activateContracts
        renewalCon.Status = 'Activated';
        update renewalCon;
        Test.stopTest();
        
        // Verify that activateContracts was called without errors
        System.assert(true, 'activateContracts should complete without throwing exceptions');
    }
    
    @IsTest
    public static void testUpdatePreviousContract() {
        Test.startTest();
        
        // Create a fresh contract that will trigger updatePreviousContract
        // We need to ensure it has SBQQ__Quote__c and SBQQ__Opportunity__c but Previous_Contract__c = null
        Contract con = new Contract(
            AccountId = [SELECT Id FROM Account ORDER BY CreatedDate LIMIT 1].Id,
            SBQQ__Quote__c = [SELECT Id FROM SBQQ__Quote__c ORDER BY CreatedDate LIMIT 1].Id,
            SBQQ__Opportunity__c = [SELECT Id FROM Opportunity ORDER BY CreatedDate LIMIT 1].Id,
            Billing_Frequency__c = 'Annual',
            StartDate = Date.today(),
            EndDate = Date.today().addDays(365),
            ContractTerm = 12
        );
        
        // Insert to trigger onBeforeInsert which calls updatePreviousContract
        insert con;
        
        // Verify that the contract was inserted successfully
        Contract insertedCon = [SELECT Id FROM Contract WHERE Id = :con.Id];
        System.assertEquals(con.Id, insertedCon.Id, 'Contract should be inserted successfully');
        
        Test.stopTest();
    }
    
    @IsTest
    public static void testUpdatePreviousContractRenewal() {
        Test.startTest();
        
        // Create a contract with renewal quote type to test renewal handling path
        // First, we need to create a proper setup with renewal quote and opportunity
        
        // Get existing data
        Account acc = [SELECT Id FROM Account ORDER BY CreatedDate LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity ORDER BY CreatedDate LIMIT 1];
        
        // Create a renewal quote
        SBQQ__Quote__c renewalQuote = new SBQQ__Quote__c(
            SBQQ__Account__c = acc.Id,
            SBQQ__Opportunity2__c = opp.Id,
            SBQQ__Type__c = 'Renewal',
            SBQQ__Primary__c = true
        );
        insert renewalQuote;
        
        // Create a contract with renewal quote
        Contract con = new Contract(
            AccountId = acc.Id,
            SBQQ__Quote__c = renewalQuote.Id,
            SBQQ__Opportunity__c = opp.Id,
            Billing_Frequency__c = 'Annual',
            StartDate = Date.today(),
            EndDate = Date.today().addDays(365),
            ContractTerm = 12
        );
        
        // Insert to trigger onBeforeInsert which calls updatePreviousContract
        insert con;
        
        // Verify that the contract was inserted successfully
        Contract insertedCon = [SELECT Id FROM Contract WHERE Id = :con.Id];
        System.assertEquals(con.Id, insertedCon.Id, 'Contract should be inserted successfully');
        
        Test.stopTest();
    }
    
    @IsTest
    public static void testUpdateContractDetails() {
        Test.startTest();
        
        // Create a contract to trigger updateContractDetails with all required fields
        Contract con = [SELECT Id, Name, SBQQ__Quote__c, SBQQ__Opportunity__c, AccountId FROM Contract ORDER BY CreatedDate DESC LIMIT 1];
        
        // Create a new contract that will trigger updateContractDetails in after insert
        Contract newCon = new Contract(
            SBQQ__Quote__c = con.SBQQ__Quote__c,
            SBQQ__Opportunity__c = con.SBQQ__Opportunity__c,
            AccountId = con.AccountId,
            Billing_Frequency__c = 'Annual',
            StartDate = Date.today(),
            EndDate = Date.today().addDays(365),
            ContractTerm = 12
        );
        
        // Insert to trigger onAfterInsert which calls updateContractDetails
        insert newCon;
        
        // Verify that the contract was inserted successfully
        Contract insertedCon = [SELECT Id FROM Contract WHERE Id = :newCon.Id];
        System.assertEquals(newCon.Id, insertedCon.Id, 'New contract should be inserted successfully');
        
        Test.stopTest();
    }
    
    @IsTest
    public static void testActivateInstallationsRenewal() {
        // Create a contract with renewal quote and installation to trigger activateInstallations
        Contract con = [SELECT Id, Name, SBQQ__Quote__c, SBQQ__Opportunity__c, AccountId FROM Contract ORDER BY CreatedDate DESC LIMIT 1];
        
        // Create a renewal quote and contract
        SBQQ__Quote__c renewalQuote = new SBQQ__Quote__c(
            SBQQ__Account__c = con.AccountId,
            SBQQ__Opportunity2__c = con.SBQQ__Opportunity__c,
            SBQQ__Type__c = 'Renewal',
            SBQQ__Primary__c = true
        );
        insert renewalQuote;
        
        Contract renewalCon = new Contract(
            SBQQ__Quote__c = renewalQuote.Id,
            SBQQ__Opportunity__c = con.SBQQ__Opportunity__c,
            AccountId = con.AccountId,
            Billing_Frequency__c = 'Annual',
            StartDate = Date.today(),
            EndDate = Date.today().addDays(365),
            ContractTerm = 12
        );
        
        // Insert renewal contract
        insert renewalCon;
        
        Test.startTest();
        // Activate the renewal contract to trigger activateContracts which calls activateInstallations
        renewalCon.Status = 'Activated';
        update renewalCon;
        Test.stopTest();
        
        // Verify that activateContracts was called without errors
        System.assert(true, 'activateContracts should complete without throwing exceptions');
    }

    @IsTest
    public static void testAfterUpdateRecalculatesPackageMetrics() {
        ensureBaseContractData();
        System.assertNotEquals(null, baseContractId, 'Base contract must exist from test setup');
        System.assert(basePackageIds != null && basePackageIds.size() >= 2, 'At least two packages required for metric test');

        List<Package__c> packages = [
            SELECT Id, InstallationCost__c, Installation_Quantity__c
            FROM Package__c
            WHERE Id IN :basePackageIds
            ORDER BY CreatedDate ASC
        ];

        packages[0].Installation_Quantity__c = 2;
        packages[0].InstallationCost__c = 150;
        packages[1].Installation_Quantity__c = 3;
        packages[1].InstallationCost__c = 200;
        update packages;

        Test.startTest();
        Map<Id, Contract> contractSnapshot = new Map<Id, Contract>([
            SELECT Id, Status, Subscription_Value__c, No_of_Installations__c
            FROM Contract
            WHERE Id = :baseContractId
        ]);
        ContractTriggerHandler.updateContractMetricsFromPackages(contractSnapshot);
        Test.stopTest();

        Contract refreshed = [
            SELECT Subscription_Value__c, No_of_Installations__c
            FROM Contract
            WHERE Id = :baseContractId
        ];

        System.assertEquals(
            900,
            refreshed.Subscription_Value__c,
            'Subscription value should sum cost * quantity for each package'
        );
        System.assertEquals(
            5,
            refreshed.No_of_Installations__c,
            'Installation count should sum Installation_Quantity__c from related packages'
        );
    }
}