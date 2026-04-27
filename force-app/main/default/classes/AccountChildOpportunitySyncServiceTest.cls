@IsTest
private class AccountChildOpportunitySyncServiceTest {
    @TestSetup
    static void setupData() {
        Account accountRec = new Account(
            Name = 'Child Opp Sync Account',
            Customer_Status__c = 'Prospect',
            CurrencyIsoCode = 'USD',
            Fleet_Contracted_Fleet_Size__c = 10,
            Fleet_Contracted_Shore_Size__c = 2,
            Fleet_Subscription_Annual_Order_Value__c = 1000
        );
        insert accountRec;

        Product_Solutions__c productSolution = new Product_Solutions__c(
            Account_ID__c = accountRec.Id,
            Product_Area_Status__c = 'Prospect',
            Product_Solution__c = 'Technical Ship Management'
        );
        insert productSolution;

        insert new Opportunity(
            AccountId = accountRec.Id,
            CloseDate = Date.today().addDays(30),
            StageName = 'Prospecting & Qualifying',
            Business_Unit__c = 'Technical Ship Management',
            LeadSource = 'Existing Customer Relationship',
            Sales_Type__c = 'Subscription',
            Existing_Opportunity_Type__c = 'Whitespace',
            Product_Solutions__c = productSolution.Id,
            Account_Name__c = 'Old Account Name',
            Account_Customer_Status__c = 'Lost',
            Customer_Status_List__c = 'Prospect',
            Account_Contracted_Fleet_Size__c = 1,
            Account_Contracted_Shore_Size__c = 1,
            Account_Subscription_Annual_Order_Value__c = 1,
            Amount = 1000,
            CurrencyIsoCode = 'USD'
        );
    }

    @IsTest
    static void accountUpdateSyncsOpenChildOpportunities() {
        Account accountRec = [
            SELECT Id, Name, Customer_Status__c, Fleet_Contracted_Fleet_Size__c,
                Fleet_Contracted_Shore_Size__c, Fleet_Subscription_Annual_Order_Value__c
            FROM Account
            WHERE Name = 'Child Opp Sync Account'
            LIMIT 1
        ];

        Test.startTest();
        accountRec.Name = 'Child Opp Sync Account Updated';
        accountRec.Customer_Status__c = 'Active';
        accountRec.Fleet_Contracted_Fleet_Size__c = 25;
        accountRec.Fleet_Contracted_Shore_Size__c = 5;
        accountRec.Fleet_Subscription_Annual_Order_Value__c = 2500;
        update accountRec;
        Test.stopTest();

        Opportunity refreshed = [
            SELECT Account_Name__c, Customer_Status_List__c, Account_Customer_Status__c,
                Account_Contracted_Fleet_Size__c, Account_Contracted_Shore_Size__c,
                Account_Subscription_Annual_Order_Value__c, Existing_Opportunity_Type__c,
                Contract_Type__c
            FROM Opportunity
            WHERE AccountId = :accountRec.Id
            LIMIT 1
        ];

        System.assertEquals('Child Opp Sync Account Updated', refreshed.Account_Name__c);
        System.assertEquals('Active', refreshed.Customer_Status_List__c);
        System.assertEquals('Prospect', refreshed.Account_Customer_Status__c);
        System.assertEquals(25, refreshed.Account_Contracted_Fleet_Size__c);
        System.assertEquals(5, refreshed.Account_Contracted_Shore_Size__c);
        System.assertEquals(2500, refreshed.Account_Subscription_Annual_Order_Value__c);
        System.assertEquals('Cross-sell', refreshed.Existing_Opportunity_Type__c);
        System.assertEquals('New Contract', refreshed.Contract_Type__c);
    }

    @IsTest
    static void automationBypassSkipsSync() {
        Account accountRec = [
            SELECT Id, Name, Customer_Status__c
            FROM Account
            WHERE Name = 'Child Opp Sync Account'
            LIMIT 1
        ];

        AutomationBypass.enableTxn(AccountChildOpportunitySyncService.BYPASS_KEY);
        Opportunity beforeBypass = [
            SELECT Account_Name__c, Existing_Opportunity_Type__c
            FROM Opportunity
            WHERE AccountId = :accountRec.Id
            LIMIT 1
        ];
        try {
            AccountChildOpportunitySyncService.syncOpenOpportunities(new Set<Id>{accountRec.Id});
        } finally {
            AutomationBypass.clearTxn();
        }

        Opportunity refreshed = [
            SELECT Account_Name__c, Existing_Opportunity_Type__c
            FROM Opportunity
            WHERE AccountId = :accountRec.Id
            LIMIT 1
        ];

        System.assertEquals(beforeBypass.Account_Name__c, refreshed.Account_Name__c);
        System.assertEquals(beforeBypass.Existing_Opportunity_Type__c, refreshed.Existing_Opportunity_Type__c);
    }

    @IsTest
    static void syncHandlesActiveCustomerAndActiveProductAreaAsUpsell() {
        Account accountRec = new Account(
            Name = 'Learning Account',
            Customer_Status__c = 'Active',
            CurrencyIsoCode = 'USD',
            L_A_Contracted_Fleet_Size__c = 12,
            L_A_Contracted_Shore_Size__c = 4,
            L_A_Subscription_Annual_Order_Value__c = 1200
        );
        insert accountRec;

        Product_Solutions__c productSolution = new Product_Solutions__c(
            Account_ID__c = accountRec.Id,
            Product_Area_Status__c = 'Active',
            Product_Solution__c = 'HCM Learning, Assessment and Competency'
        );
        insert productSolution;

        Opportunity opportunityRec = new Opportunity(
            AccountId = accountRec.Id,
            CloseDate = Date.today().addDays(30),
            StageName = 'Prospecting & Qualifying',
            Business_Unit__c = 'HCM Learning, Assessment and Competency',
            LeadSource = 'Existing Customer Relationship',
            Sales_Type__c = 'Subscription',
            Existing_Opportunity_Type__c = 'Whitespace',
            Product_Solutions__c = productSolution.Id,
            Amount = 1200,
            CurrencyIsoCode = 'USD'
        );
        insert opportunityRec;

        Test.startTest();
        AccountChildOpportunitySyncService.syncOpenOpportunities(new Set<Id>{accountRec.Id});
        Test.stopTest();

        Opportunity refreshed = [
            SELECT Existing_Opportunity_Type__c, Contract_Type__c,
                Account_Contracted_Fleet_Size__c, Account_Contracted_Shore_Size__c,
                Account_Subscription_Annual_Order_Value__c
            FROM Opportunity
            WHERE Id = :opportunityRec.Id
        ];

        System.assertEquals(12, refreshed.Account_Contracted_Fleet_Size__c);
        System.assertEquals(4, refreshed.Account_Contracted_Shore_Size__c);
        System.assertEquals(1200, refreshed.Account_Subscription_Annual_Order_Value__c);
    }

    @IsTest
    static void accountTriggerRoutesDeleteAndUndeleteContexts() {
        Account accountRec = new Account(
            Name = 'Account Trigger Lifecycle',
            Customer_Status__c = 'Prospect',
            CurrencyIsoCode = 'USD'
        );
        insert accountRec;

        Test.startTest();
        delete accountRec;
        undelete accountRec;
        Test.stopTest();

        Account restored = [
            SELECT Id, Name
            FROM Account
            WHERE Id = :accountRec.Id
        ];
        System.assertEquals('Account Trigger Lifecycle', restored.Name);
    }
}
