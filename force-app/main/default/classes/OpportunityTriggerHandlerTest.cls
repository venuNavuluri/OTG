@IsTest
private class OpportunityTriggerHandlerTest {
    @TestSetup
    static void setupTestData()
    {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        List<Sales_Person_Role_Mapping__mdt> roleMappings = [SELECT Id, MasterLabel, DeveloperName FROM Sales_Person_Role_Mapping__mdt];
        //UserRole uRole = [SELECT Id FROM UserRole WHERE Name = :roleMappings[0].MasterLabel];
        UserRole uRole = [SELECT Id FROM UserRole LIMIT 1];
        
        User defaultUser = new User(Username='bgotgtestdefault@test.com', LastName='bg_AccountUtilsTest');
        defaultUser.Email = 'bgotgtest@test.com';
        defaultUser.Alias = 'bgotg';
        defaultUser.TimeZoneSidKey = 'Europe/London';
        defaultUser.LocaleSidKey = 'en_GB';
        defaultUser.EmailEncodingKey = 'UTF-8';
        defaultUser.ProfileId = p.Id;
        defaultUser.LanguageLocaleKey = 'en_US';
        defaultUser.UserRoleId = uRole.Id;
        insert defaultUser;
    }
    @IsTest
    static void testAmendedContractValueSync() {
        User defaultUser = [select Id from User where Email = 'bgotgtest@test.com' limit 1];
        Id countryId = TestDataFactory_OTG.getOrCreateCountryMappingId('Americas');
        Country_Mapping__c cm = [select Id, Default_Account_Owner__c from Country_Mapping__c where Id = :countryId];
        cm.Default_Account_Owner__c = defaultUser.Id;
        update cm;
        
        Account account = TestDataFactory_OTG.createB2BAccount(UserInfo.getUserId(), countryId, 'Opp Value Sync');
        Legal_Entity__c legalEntity = TestDataFactory_OTG.createLegalEntity(countryId);

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = account.Id,
            CloseDate = Date.today().addDays(30),
            StageName = 'Prospecting & Qualifying',
            Business_Unit__c = 'HCM Learning, Assessment and Competency',
            Product_Group__c = 'OLP',
            LeadSource = 'Existing Customer Relationship',
            Sales_Type__c = 'Subscription',
            Amount = 1000,
            Legal_Entity__c = legalEntity.Id,
            CurrencyIsoCode = 'USD'
        );
        insert opp;

        Contract amendedContract = new Contract(
            AccountId = account.Id,
            Status = 'Draft',
            StartDate = Date.today(),
            ContractTerm = 12,
            SBQQ__Opportunity__c = opp.Id,
            Subscription_Value__c = 2500,
            CurrencyIsoCode = 'USD'
        );
        insert amendedContract;

        opp = [
            SELECT Account_Subscription_Annual_Order_Value__c, Product_Group__c
            FROM Opportunity
            WHERE Id = :opp.Id
        ];

        opp.Business_Unit__c = 'HCM Learning, Assessment and Competency';
        opp.Account_Subscription_Annual_Order_Value__c = 0;
        opp.SBQQ__AmendedContract__c = amendedContract.Id;

        Test.startTest();
        update opp;
        Test.stopTest();

        Opportunity refreshed = [
            SELECT Account_Subscription_Annual_Order_Value__c, SBQQ__AmendedContract__c
            FROM Opportunity
            WHERE Id = :opp.Id
        ];

        System.assertEquals(amendedContract.Id, refreshed.SBQQ__AmendedContract__c, 'Amended contract should stay linked');
        System.assertEquals(
            2500,
            refreshed.Account_Subscription_Annual_Order_Value__c,
            'Annual value should mirror the amended contract subscription value'
        );
    }

    @IsTest
    static void testAmendedContractSelectionSyncsBeforeSaveFields() {
        User defaultUser = [select Id from User where Email = 'bgotgtest@test.com' limit 1];
        Id countryId = TestDataFactory_OTG.getOrCreateCountryMappingId('Americas');
        Country_Mapping__c cm = [select Id, Default_Account_Owner__c from Country_Mapping__c where Id = :countryId];
        cm.Default_Account_Owner__c = defaultUser.Id;
        update cm;

        Account account = TestDataFactory_OTG.createB2BAccount(UserInfo.getUserId(), countryId, 'Amend Selection Sync');
        Legal_Entity__c legalEntity = TestDataFactory_OTG.createLegalEntity(countryId);

        Opportunity opp = new Opportunity(
            Name = 'Amend Selection Opportunity',
            AccountId = account.Id,
            CloseDate = Date.today().addDays(30),
            StageName = 'Prospecting & Qualifying',
            Business_Unit__c = 'HCM Learning, Assessment and Competency',
            Product_Group__c = 'OLP',
            LeadSource = 'Existing Customer Relationship',
            Sales_Type__c = 'Subscription',
            Amount = 1000,
            Legal_Entity__c = legalEntity.Id,
            CurrencyIsoCode = 'USD'
        );
        insert opp;

        Contract amendedContract = new Contract(
            AccountId = account.Id,
            Status = 'Draft',
            StartDate = Date.today(),
            ContractTerm = 12,
            SBQQ__Opportunity__c = opp.Id,
            Subscription_Value__c = 3456,
            CurrencyIsoCode = 'USD'
        );
        insert amendedContract;

        opp = [
            SELECT Amend_Contract_Sales__c
            FROM Opportunity
            WHERE Id = :opp.Id
        ];
        opp.Amend_Contract_Sales__c = amendedContract.Id;

        Test.startTest();
        update opp;
        Test.stopTest();

        Opportunity refreshed = [
            SELECT Amend_Contract_Sales__c, SBQQ__AmendedContract__c,
                Account_Subscription_Annual_Order_Value__c, CurrencyIsoCode
            FROM Opportunity
            WHERE Id = :opp.Id
        ];

        System.assertEquals(amendedContract.Id, refreshed.Amend_Contract_Sales__c);
        System.assertEquals(amendedContract.Id, refreshed.SBQQ__AmendedContract__c);
        System.assertEquals(3456, refreshed.Account_Subscription_Annual_Order_Value__c);
        System.assertEquals('USD', refreshed.CurrencyIsoCode);
    }

    @IsTest
    static void testUpdateContractAmendedWrapperDelegatesToHandler() {
        Account accountRec = new Account(
            Name = 'Wrapper Account',
            Customer_Status__c = 'Active',
            CurrencyIsoCode = 'USD'
        );
        insert accountRec;

        Contract amendedContract = new Contract(
            AccountId = accountRec.Id,
            Status = 'Draft',
            StartDate = Date.today(),
            ContractTerm = 12,
            Subscription_Value__c = 789,
            CurrencyIsoCode = 'USD'
        );
        insert amendedContract;

        Id opportunityId = Schema.SObjectType.Opportunity.getKeyPrefix() + '000000000001';
        Opportunity oldOpportunity = new Opportunity(
            Id = opportunityId
        );
        Opportunity newOpportunity = new Opportunity(
            Id = opportunityId,
            Amend_Contract_Sales__c = amendedContract.Id
        );

        UpdateContractAmended.updateAmendContract(
            new List<Opportunity>{ newOpportunity },
            new Map<Id, Opportunity>{ oldOpportunity.Id => oldOpportunity }
        );

        System.assertEquals(amendedContract.Id, newOpportunity.SBQQ__AmendedContract__c);
        System.assertEquals(789, newOpportunity.Account_Subscription_Annual_Order_Value__c);
        System.assertEquals('USD', newOpportunity.CurrencyIsoCode);
    }

    @IsTest
    static void testRenewalContractValueSync_usesRenewedContractWhenNoAmendment() {
        User defaultUser = [select Id from User where Email = 'bgotgtest@test.com' limit 1];
        Id countryId = TestDataFactory_OTG.getOrCreateCountryMappingId('Americas');
        Country_Mapping__c cm = [select Id, Default_Account_Owner__c from Country_Mapping__c where Id = :countryId];
        cm.Default_Account_Owner__c = defaultUser.Id;
        update cm;
        
        Account account = TestDataFactory_OTG.createB2BAccount(UserInfo.getUserId(), countryId, 'Renewal Opp Value Sync');
        Legal_Entity__c legalEntity = TestDataFactory_OTG.createLegalEntity(countryId);

        Opportunity opp = new Opportunity(
            Name = 'Renewal Opportunity',
            AccountId = account.Id,
            CloseDate = Date.today().addDays(30),
            StageName = 'Prospecting & Qualifying',
            Business_Unit__c = 'HCM Learning, Assessment and Competency',
            Product_Group__c = 'OLP',
            LeadSource = 'Existing Customer Relationship',
            Sales_Type__c = 'Subscription',
            Amount = 5000,
            Legal_Entity__c = legalEntity.Id,
            CurrencyIsoCode = 'USD'
        );
        insert opp;

        Contract renewedContract = new Contract(
            AccountId = account.Id,
            Status = 'Draft',
            StartDate = Date.today().addYears(-1),
            ContractTerm = 12,
            SBQQ__Opportunity__c = opp.Id,
            Subscription_Value__c = 1000,
            CurrencyIsoCode = 'USD'
        );
        insert renewedContract;

        opp = [
            SELECT Account_Subscription_Annual_Order_Value__c, Product_Group__c
            FROM Opportunity
            WHERE Id = :opp.Id
        ];

        opp.Account_Subscription_Annual_Order_Value__c = 0;
        opp.Existing_Opportunity_Type__c = 'Renewal';
        opp.SBQQ__RenewedContract__c = renewedContract.Id;
        opp.SBQQ__AmendedContract__c = null;

        Test.startTest();
        update opp;
        Test.stopTest();

        Opportunity refreshed = [
            SELECT Account_Subscription_Annual_Order_Value__c, SBQQ__RenewedContract__c
            FROM Opportunity
            WHERE Id = :opp.Id
        ];

        System.assertEquals(renewedContract.Id, refreshed.SBQQ__RenewedContract__c, 'Renewed contract should stay linked');
        System.assertEquals(
            1000,
            refreshed.Account_Subscription_Annual_Order_Value__c,
            'Annual value should mirror the contract subscription value even for renewals'
        );
    }

    @IsTest
    static void testActiveAccountAndProspectProductAreaCreatesCrossSell() {
        Account accountRec = new Account(
            Name = 'Active Account Prospect Product Area',
            Customer_Status__c = 'Active',
            CurrencyIsoCode = 'USD'
        );
        insert accountRec;

        Product_Solutions__c productSolution = getOrCreateProductSolution(
            accountRec.Id,
            'HCM Learning, Assessment and Competency',
            'Prospect'
        );

        Opportunity opportunityRec = new Opportunity(
            Name = 'HCM LAC Prospect Area',
            AccountId = accountRec.Id,
            CloseDate = Date.today().addDays(30),
            StageName = 'Prospecting & Qualifying',
            Business_Unit__c = 'HCM Learning, Assessment and Competency',
            Product_Group__c = 'OLP',
            LeadSource = 'Existing Customer Relationship',
            Sales_Type__c = 'Subscription',
            Existing_Opportunity_Type__c = 'Whitespace',
            Product_Solutions__c = productSolution.Id,
            Amount = 1000,
            CurrencyIsoCode = 'USD'
        );

        Test.startTest();
        insert opportunityRec;
        Test.stopTest();

        Opportunity refreshed = [
            SELECT Existing_Opportunity_Type__c, Contract_Type__c, Account_Customer_Status__c,
                Customer_Status_List__c, Product_Solutions__c, Name
            FROM Opportunity
            WHERE Id = :opportunityRec.Id
        ];

        System.assertEquals('Cross-sell', refreshed.Existing_Opportunity_Type__c);
        System.assert(refreshed.Name.contains('/ Cross-sell/'), 'Opportunity name should use the final Cross-sell type: ' + refreshed.Name);
        System.assertEquals('New Contract', refreshed.Contract_Type__c);
        System.assertEquals('Prospect', refreshed.Account_Customer_Status__c);
        System.assertEquals('Active', refreshed.Customer_Status_List__c);
        System.assertEquals(productSolution.Id, refreshed.Product_Solutions__c);
    }

    @IsTest
    static void testActiveAccountAndActiveProductAreaCreatesUpsell() {
        Account accountRec = new Account(
            Name = 'Active Account Active Product Area',
            Customer_Status__c = 'Active',
            CurrencyIsoCode = 'USD'
        );
        insert accountRec;

        Product_Solutions__c productSolution = getOrCreateProductSolution(
            accountRec.Id,
            'Technical Ship Management',
            'Active'
        );

        Opportunity opportunityRec = new Opportunity(
            Name = 'TSM Active Area',
            AccountId = accountRec.Id,
            CloseDate = Date.today().addDays(30),
            StageName = 'Prospecting & Qualifying',
            Business_Unit__c = 'Technical Ship Management',
            LeadSource = 'Existing Customer Relationship',
            Sales_Type__c = 'Subscription',
            Existing_Opportunity_Type__c = 'Whitespace',
            Product_Solutions__c = productSolution.Id,
            Amount = 1000,
            CurrencyIsoCode = 'USD'
        );

        Test.startTest();
        insert opportunityRec;
        Test.stopTest();

        Opportunity refreshed = [
            SELECT Existing_Opportunity_Type__c, Contract_Type__c, Account_Customer_Status__c,
                Customer_Status_List__c, Name
            FROM Opportunity
            WHERE Id = :opportunityRec.Id
        ];

        System.assertEquals('Up-sell', refreshed.Existing_Opportunity_Type__c);
        System.assert(refreshed.Name.contains('/ Up-sell/'), 'Opportunity name should use the final Up-sell type: ' + refreshed.Name);
        System.assertEquals('Existing Contract', refreshed.Contract_Type__c);
        System.assertEquals('Active', refreshed.Account_Customer_Status__c);
        System.assertEquals('Active', refreshed.Customer_Status_List__c);
    }

    @IsTest
    static void testAccountChangeRelinksProductSolutionAndRecalculatesType() {
        Account originalAccount = new Account(
            Name = 'Original Prospect Account',
            Customer_Status__c = 'Active',
            CurrencyIsoCode = 'USD'
        );
        Account targetAccount = new Account(
            Name = 'Target Active Account',
            Customer_Status__c = 'Active',
            CurrencyIsoCode = 'USD'
        );
        insert new List<Account>{ originalAccount, targetAccount };

        Product_Solutions__c originalProductSolution = getOrCreateProductSolution(
            originalAccount.Id,
            'Technical Ship Management',
            'Prospect'
        );
        Product_Solutions__c targetProductSolution = getOrCreateProductSolution(
            targetAccount.Id,
            'Technical Ship Management',
            'Active'
        );

        Opportunity opportunityRec = new Opportunity(
            Name = 'TSM Account Change',
            AccountId = originalAccount.Id,
            CloseDate = Date.today().addDays(30),
            StageName = 'Prospecting & Qualifying',
            Business_Unit__c = 'Technical Ship Management',
            Product_Group__c = 'TM Master',
            LeadSource = 'Existing Customer Relationship',
            Sales_Type__c = 'Subscription',
            Existing_Opportunity_Type__c = 'Whitespace',
            Product_Solutions__c = originalProductSolution.Id,
            Amount = 1000,
            CurrencyIsoCode = 'USD'
        );
        insert opportunityRec;

        Test.startTest();
        opportunityRec.AccountId = targetAccount.Id;
        update opportunityRec;
        Test.stopTest();

        Opportunity refreshed = [
            SELECT Existing_Opportunity_Type__c, Contract_Type__c, Product_Solutions__c,
                Account_Customer_Status__c, Customer_Status_List__c, Name
            FROM Opportunity
            WHERE Id = :opportunityRec.Id
        ];

        System.assertEquals('Up-sell', refreshed.Existing_Opportunity_Type__c);
        System.assertEquals('Existing Contract', refreshed.Contract_Type__c);
        System.assertEquals(targetProductSolution.Id, refreshed.Product_Solutions__c);
        System.assertEquals('Active', refreshed.Account_Customer_Status__c);
        System.assertEquals('Active', refreshed.Customer_Status_List__c);
        System.assert(refreshed.Name.contains('/ Up-sell/'), 'Opportunity name should use recalculated Up-sell type: ' + refreshed.Name);
    }

    @IsTest
    static void testOneTimeOpportunityNameUsesFinalType() {
        Account accountRec = new Account(
            Name = 'One Time Account',
            Customer_Status__c = 'Prospect',
            CurrencyIsoCode = 'USD'
        );
        insert accountRec;

        Opportunity opportunityRec = new Opportunity(
            Name = 'One Time Opportunity',
            AccountId = accountRec.Id,
            CloseDate = Date.today().addDays(30),
            StageName = 'Prospecting & Qualifying',
            Business_Unit__c = 'Voyage Performance & Optimization',
            LeadSource = 'Existing Customer Relationship',
            Sales_Type__c = 'One-Time',
            Existing_Opportunity_Type__c = 'Whitespace',
            Amount = 1000,
            CurrencyIsoCode = 'USD'
        );

        Test.startTest();
        insert opportunityRec;
        Test.stopTest();

        Opportunity refreshed = [
            SELECT Existing_Opportunity_Type__c, Name
            FROM Opportunity
            WHERE Id = :opportunityRec.Id
        ];

        System.assertEquals('One-Time', refreshed.Existing_Opportunity_Type__c);
        System.assert(refreshed.Name.contains('/ One-Time/'), 'Opportunity name should use the final One-Time type: ' + refreshed.Name);
    }

    @IsTest
    static void testOpportunityHandlerSupportsBeforeInsertBulkNameGeneration() {
        Account firstAccount = new Account(
            Name = 'Bulk Name Account One',
            Customer_Status__c = 'Active',
            CurrencyIsoCode = 'USD'
        );
        Account secondAccount = new Account(
            Name = 'Bulk Name Account Two',
            Customer_Status__c = 'Prospect',
            CurrencyIsoCode = 'USD'
        );
        insert new List<Account>{ firstAccount, secondAccount };

        Product_Solutions__c activeProductSolution = getOrCreateProductSolution(
            firstAccount.Id,
            'Technical Ship Management',
            'Active'
        );

        List<Opportunity> opportunities = new List<Opportunity>{
            new Opportunity(
                Name = 'Pending Name One',
                AccountId = firstAccount.Id,
                CloseDate = Date.today().addDays(30),
                StageName = 'Prospecting & Qualifying',
                Business_Unit__c = 'Technical Ship Management',
                Account_Customer_Status__c = 'Active',
                LeadSource = 'Existing Customer Relationship',
                Sales_Type__c = 'Subscription',
                Existing_Opportunity_Type__c = 'Up-sell',
                Product_Solutions__c = activeProductSolution.Id,
                Amount = 1000,
                CurrencyIsoCode = 'USD'
            ),
            new Opportunity(
                Name = 'Pending Name Two',
                AccountId = secondAccount.Id,
                CloseDate = Date.today().addDays(30),
                StageName = 'Prospecting & Qualifying',
                Business_Unit__c = 'Voyage Performance & Optimization',
                LeadSource = 'Existing Customer Relationship',
                Sales_Type__c = 'One-Time',
                Existing_Opportunity_Type__c = 'Whitespace',
                Amount = 1000,
                CurrencyIsoCode = 'USD'
            )
        };

        Test.startTest();
        insert opportunities;
        Test.stopTest();

        Set<Id> opportunityIds = new Map<Id, Opportunity>(opportunities).keySet();
        Map<Id, Opportunity> refreshedById = new Map<Id, Opportunity>([
            SELECT Name
            FROM Opportunity
            WHERE Id IN :opportunityIds
        ]);

        System.assert(refreshedById.get(opportunities[0].Id).Name.contains('TSM/ Existing Customer/ Up-sell/ Bulk Name Account One'));
        System.assert(refreshedById.get(opportunities[1].Id).Name.contains('VPO/ New Customer/ One-Time/ Bulk Name Account Two'));
    }

    @IsTest
    static void testOpportunityStageRegressionClearsApprovalStatus() {
        Id opportunityId = Schema.SObjectType.Opportunity.getKeyPrefix() + '000000000001';
        Opportunity oldOpportunity = new Opportunity(
            Id = opportunityId,
            StageName = 'Proposal Review',
            Approval_Status__c = 'Approved'
        );
        Opportunity newOpportunity = new Opportunity(
            Id = opportunityId,
            StageName = 'Proposal / Quote',
            Approval_Status__c = 'Approved'
        );

        bg_OpportunityUtils.handleBeforeUpdate(
            new List<Opportunity>{ newOpportunity },
            new Map<Id, Opportunity>{ oldOpportunity.Id => oldOpportunity }
        );

        System.assertEquals(null, newOpportunity.Approval_Status__c);
    }

    @IsTest
    static void testSpecialOpportunityTypesArePreserved() {
        Account accountRec = new Account(
            Name = 'Special Opportunity Type Account',
            Customer_Status__c = 'Active',
            CurrencyIsoCode = 'USD'
        );
        insert accountRec;

        Product_Solutions__c productSolution = getOrCreateProductSolution(
            accountRec.Id,
            'HCM Learning, Assessment and Competency',
            'Prospect'
        );

        Opportunity opportunityRec = new Opportunity(
            Name = 'Account Growth Preservation',
            AccountId = accountRec.Id,
            CloseDate = Date.today().addDays(30),
            StageName = 'Prospecting & Qualifying',
            Business_Unit__c = 'HCM Learning, Assessment and Competency',
            LeadSource = 'Existing Customer Relationship',
            Sales_Type__c = 'Subscription',
            Existing_Opportunity_Type__c = 'Account Growth',
            Product_Solutions__c = productSolution.Id,
            Amount = 1000,
            CurrencyIsoCode = 'USD'
        );

        Test.startTest();
        insert opportunityRec;
        Test.stopTest();

        Opportunity refreshed = [
            SELECT Existing_Opportunity_Type__c
            FROM Opportunity
            WHERE Id = :opportunityRec.Id
        ];

        System.assertEquals('Account Growth', refreshed.Existing_Opportunity_Type__c);
    }

    private static Product_Solutions__c getOrCreateProductSolution(Id accountId, String businessUnit, String status) {
        List<Product_Solutions__c> existingProductSolutions = [
            SELECT Id, Product_Area_Status__c
            FROM Product_Solutions__c
            WHERE Account_ID__c = :accountId
              AND Product_Solution__c = :businessUnit
            LIMIT 1
        ];
        if (!existingProductSolutions.isEmpty()) {
            Product_Solutions__c productSolution = existingProductSolutions[0];
            productSolution.Product_Area_Status__c = status;
            update productSolution;
            return productSolution;
        }

        Product_Solutions__c productSolution = new Product_Solutions__c(
            Account_ID__c = accountId,
            Product_Area_Status__c = status,
            Product_Solution__c = businessUnit
        );
        insert productSolution;
        return productSolution;
    }
}
