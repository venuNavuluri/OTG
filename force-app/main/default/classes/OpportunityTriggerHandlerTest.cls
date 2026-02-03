@IsTest
private class OpportunityTriggerHandlerTest {
    @TestSetup
    static void setupTestData()
    {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        List<Sales_Person_Role_Mapping__mdt> roleMappings = [SELECT Id, MasterLabel, DeveloperName FROM Sales_Person_Role_Mapping__mdt];
        UserRole uRole = [SELECT Id FROM UserRole WHERE Name = :roleMappings[0].MasterLabel];
        
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
        VRConfiguration__c config = VRConfiguration__c.getOrgDefaults();
        if (config == null) {
            config = new VRConfiguration__c();
        }
        config.ByPass_Opportunity_Triggers__c = true;
        upsert config;

        User defaultUser = [select Id from User where Email = 'bgotgtest@test.com' limit 1];
        Id countryId = TestDataFactory_OTG.getOrCreateCountryMappingId('Americas');
        Country_Mapping__c cm = [select Id, Default_Account_Owner__c from Country_Mapping__c where Id = :countryId];
        cm.Default_Account_Owner__c = defaultUser.Id;
        update cm;
        
        Account account = TestDataFactory_OTG.createB2BAccount(UserInfo.getUserId(), countryId, 'Opp Value Sync');
        Legal_Entity__c legalEntity = TestDataFactory_OTG.createLegalEntity(countryId);

        String hcmProductGroup = null;
        for (Schema.PicklistEntry entry : Opportunity.Product_Group__c.getDescribe().getPicklistValues()) {
            if (!entry.isActive()) {
                continue;
            }
            if (entry.getValue().contains('Learning')) {
                hcmProductGroup = entry.getValue();
                break;
            }
        }
        if (hcmProductGroup == null) {
            hcmProductGroup = Opportunity.Product_Group__c.getDescribe().getPicklistValues()[0].getValue();
        }

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = account.Id,
            CloseDate = Date.today().addDays(30),
            StageName = 'Prospecting & Qualifying',
            Business_Unit__c = 'HCM Learning, Assessment and Competency',
            Product_Group__c = hcmProductGroup,
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
    static void testRenewalContractValueSync_usesRenewedContractWhenNoAmendment() {
        VRConfiguration__c config = VRConfiguration__c.getOrgDefaults();
        if (config == null) {
            config = new VRConfiguration__c();
        }
        config.ByPass_Opportunity_Triggers__c = true;
        upsert config;

        User defaultUser = [select Id from User where Email = 'bgotgtest@test.com' limit 1];
        Id countryId = TestDataFactory_OTG.getOrCreateCountryMappingId('Americas');
        Country_Mapping__c cm = [select Id, Default_Account_Owner__c from Country_Mapping__c where Id = :countryId];
        cm.Default_Account_Owner__c = defaultUser.Id;
        update cm;
        
        Account account = TestDataFactory_OTG.createB2BAccount(UserInfo.getUserId(), countryId, 'Renewal Opp Value Sync');
        Legal_Entity__c legalEntity = TestDataFactory_OTG.createLegalEntity(countryId);

        String hcmProductGroup = null;
        for (Schema.PicklistEntry entry : Opportunity.Product_Group__c.getDescribe().getPicklistValues()) {
            if (!entry.isActive()) {
                continue;
            }
            if (entry.getValue().contains('Learning')) {
                hcmProductGroup = entry.getValue();
                break;
            }
        }
        if (hcmProductGroup == null) {
            hcmProductGroup = Opportunity.Product_Group__c.getDescribe().getPicklistValues()[0].getValue();
        }

        Opportunity opp = new Opportunity(
            Name = 'Renewal Opportunity',
            AccountId = account.Id,
            CloseDate = Date.today().addDays(30),
            StageName = 'Prospecting & Qualifying',
            Business_Unit__c = 'HCM Learning, Assessment and Competency',
            Product_Group__c = hcmProductGroup,
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
}