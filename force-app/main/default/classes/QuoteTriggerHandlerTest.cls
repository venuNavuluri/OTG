@IsTest
private class QuoteTriggerHandlerTest {

    // Small helper to add a line with dates spanning today
    private static SBQQ__QuoteLine__c addLine(
        Id quoteId, Id groupId, Id pbeId,
        Integer qty, Integer priorQty, Decimal net
    ) {
        Date s = Date.today(), e = s.addMonths(12);
        return TestDataFactory_OTG.createQuoteLine(
            quoteId, groupId, pbeId,
            qty, priorQty, net,
            s, e, null
        );
    }

    // ------------------------------------------------------------------
    // 1) beforeInsert: Amendment currency sync (Quote + Opportunity)
    //    - Ensure base primary quote is set to non-primary to avoid
    //      currency validation conflict from org flow/validation.
    // ------------------------------------------------------------------
    @IsTest
    static void test_beforeInsert_amendmentCurrencySync() {
        TestDataFactory_OTG.enableOrgVRConfig();
        TestDataFactory_OTG.primeDefaultOwnerAllRegions(UserInfo.getUserId());

        TestDataFactory_OTG.QuoteContext ctx =
            TestDataFactory_OTG.buildDraftQuoteContext('Americas', false, false);

        // Make the seed quote non-primary to avoid currency flow validation
        update new SBQQ__Quote__c(Id = ctx.quote.Id, SBQQ__Primary__c = false);

        // Contract in EUR -> should drive quote & opp currency
        Contract ctr = TestDataFactory_OTG.createContractBasic(
            ctx.b2bAccount.Id, 'EUR', Date.today(), 12, null
        );

        SBQQ__Quote__c amend = new SBQQ__Quote__c(
            SBQQ__Account__c        = ctx.b2bAccount.Id,
            SBQQ__Opportunity2__c   = ctx.opportunity.Id,
            SBQQ__StartDate__c      = Date.today(),
            SBQQ__Type__c           = 'Amendment',
            SBQQ__MasterContract__c = ctr.Id,
            SBQQ__PricebookId__c    = ctx.quote.SBQQ__PricebookId__c,
            SBQQ__Primary__c        = false
        );

        Test.startTest();
        insert amend; // beforeInsert should sync currencies
        Test.stopTest();

        amend = [SELECT Id, CurrencyIsoCode FROM SBQQ__Quote__c WHERE Id = :amend.Id];
        Opportunity opp = [SELECT Id, CurrencyIsoCode FROM Opportunity WHERE Id = :ctx.opportunity.Id];

        System.assertEquals('EUR', amend.CurrencyIsoCode, 'Quote currency should mirror Contract');
        System.assertEquals('EUR', opp.CurrencyIsoCode, 'Opportunity currency should mirror Contract');
    }

    // ------------------------------------------------------------------
    // 2) afterInsert: createQuoteLineGroups from Contract → Packages (Amendment)
    // ------------------------------------------------------------------
    @IsTest
    static void test_afterInsert_createQLG_fromContract_Amendment() {
        TestDataFactory_OTG.enableOrgVRConfig();
        TestDataFactory_OTG.primeDefaultOwnerAllRegions(UserInfo.getUserId());

        TestDataFactory_OTG.QuoteContext ctx =
            TestDataFactory_OTG.buildDraftQuoteContext('Americas', false, false);

        // Avoid currency validation during Amendment insert
        update new SBQQ__Quote__c(Id = ctx.quote.Id, SBQQ__Primary__c = false);

        TestDataFactory_OTG.ContractPackageContext cctx =
            TestDataFactory_OTG.buildContractWithPackages(ctx.b2bAccount.Id, 'USD', 12, 2, 2);

        SBQQ__Quote__c amend = new SBQQ__Quote__c(
            SBQQ__Account__c        = ctx.b2bAccount.Id,
            SBQQ__Opportunity2__c   = ctx.opportunity.Id,
            SBQQ__StartDate__c      = Date.today(),
            SBQQ__Type__c           = 'Amendment',
            SBQQ__MasterContract__c = cctx.contractRec.Id,
            SBQQ__PricebookId__c    = ctx.quote.SBQQ__PricebookId__c,
            SBQQ__Primary__c        = true
        );

        Test.startTest();
        insert amend; // afterInsert → createQuoteLineGroups
        Test.stopTest();

        List<SBQQ__QuoteLineGroup__c> created = [
            SELECT Id, Name, SBQQ__Quote__c, Created_From_Package__c, Package__c, Installation_Quantity__c
            FROM SBQQ__QuoteLineGroup__c
            WHERE SBQQ__Quote__c = :amend.Id
        ];
        System.assert(created.size() >= 2, 'Expected QLGs created from Contract packages');

        // Confirm the package temp linkage was set during handler logic
        Set<Id> pkgIds = new Set<Id>();
        for (Package__c p : cctx.packages) pkgIds.add(p.Id);

        Map<Id, Package__c> pkgs = new Map<Id, Package__c>([
            SELECT Id, Temp_Quote__c, Temp_Quote_Line_Group__c
            FROM Package__c
            WHERE Id IN :pkgIds
        ]);
        for (Package__c p : pkgs.values()) {
            System.assertEquals(amend.Id, p.Temp_Quote__c, 'Temp_Quote__c should be set to new quote');
            System.assertNotEquals(null, p.Temp_Quote_Line_Group__c, 'Temp_Quote_Line_Group__c should be populated');
        }
    }

    // ------------------------------------------------------------------
    // 3) afterInsert: createQuoteLineGroups using Opportunity.SBQQ__RenewedContract__c (Renewal)
    // ------------------------------------------------------------------
    @IsTest
    static void test_afterInsert_createQLG_fromRenewedContract_Renewal() {
        TestDataFactory_OTG.enableOrgVRConfig();
        TestDataFactory_OTG.primeDefaultOwnerAllRegions(UserInfo.getUserId());

        TestDataFactory_OTG.QuoteContext ctx =
            TestDataFactory_OTG.buildDraftQuoteContext('Americas', false, false);

        TestDataFactory_OTG.ContractPackageContext cctx =
            TestDataFactory_OTG.buildContractWithPackages(ctx.b2bAccount.Id, 'USD', 12, 2, 1);
        TestDataFactory_OTG.attachRenewedContractToOpportunity(ctx.opportunity.Id, cctx.contractRec.Id);

        SBQQ__Quote__c ren = new SBQQ__Quote__c(
            SBQQ__Account__c      = ctx.b2bAccount.Id,
            SBQQ__Opportunity2__c = ctx.opportunity.Id,
            SBQQ__StartDate__c    = Date.today(),
            SBQQ__Type__c         = 'Renewal',
            SBQQ__PricebookId__c  = ctx.quote.SBQQ__PricebookId__c,
            SBQQ__Primary__c      = true
        );

        Test.startTest();
        insert ren;
        Test.stopTest();

        List<SBQQ__QuoteLineGroup__c> created = [
            SELECT Id, Name, SBQQ__Quote__c, Created_From_Package__c, Package__c
            FROM SBQQ__QuoteLineGroup__c
            WHERE SBQQ__Quote__c = :ren.Id
        ];
        System.assert(created.size() >= 2, 'Expected QLGs from renewed contract packages');
    }

    // ------------------------------------------------------------------
    // 4) beforeUpdate: updateQuoteEndDate (by term) AND via Master Contract
    //    Use one startTest/stopTest in this method.
    // ------------------------------------------------------------------
    @IsTest
    static void test_beforeUpdate_updateQuoteEndDate() {
        TestDataFactory_OTG.enableOrgVRConfig();
        TestDataFactory_OTG.primeDefaultOwnerAllRegions(UserInfo.getUserId());

        TestDataFactory_OTG.QuoteContext ctx =
            TestDataFactory_OTG.buildDraftQuoteContext('Americas', false, false);

        // Prepare Amendment too
        Contract c = TestDataFactory_OTG.createContractBasic(
            ctx.b2bAccount.Id, 'USD', Date.today(), 12, Date.today().addDays(200)
        );
        SBQQ__Quote__c amend = new SBQQ__Quote__c(
            SBQQ__Account__c        = ctx.b2bAccount.Id,
            SBQQ__Opportunity2__c   = ctx.opportunity.Id,
            SBQQ__StartDate__c      = Date.today(),
            SBQQ__Type__c           = 'Amendment',
            SBQQ__MasterContract__c = c.Id,
            SBQQ__PricebookId__c    = ctx.quote.SBQQ__PricebookId__c,
            SBQQ__Primary__c        = true
        );
        insert amend;

        Test.startTest();
        // by SubscriptionTerm
        SBQQ__Quote__c qTouch = new SBQQ__Quote__c(Id = ctx.quote.Id, SBQQ__Notes__c = 'Touch for beforeUpdate');
        update qTouch;

        // by Master Contract (Amendment)
        SBQQ__Quote__c aTouch = new SBQQ__Quote__c(Id = amend.Id, SBQQ__Notes__c = 'Touch amend for beforeUpdate');
        update aTouch;
        Test.stopTest();

        SBQQ__Quote__c qAfter = [
            SELECT Id, SBQQ__StartDate__c, SBQQ__EndDate__c, SBQQ__SubscriptionTerm__c
            FROM SBQQ__Quote__c WHERE Id = :ctx.quote.Id
        ];
        Date expectedQ = qAfter.SBQQ__StartDate__c.addMonths(12).addDays(-1);
        System.assertEquals(expectedQ, qAfter.SBQQ__EndDate__c, 'EndDate should be StartDate + term - 1');

        SBQQ__Quote__c amendAfter = [
            SELECT Id, SBQQ__EndDate__c FROM SBQQ__Quote__c WHERE Id = :amend.Id
        ];
        System.assertEquals(c.EndDate, amendAfter.SBQQ__EndDate__c, 'Amendment EndDate should mirror Master Contract');
    }

    // ------------------------------------------------------------------
    // 5) afterUpdate on Approval: user-created QLG → Package__c;
    //    Installation_Price__c should equal SUM(ASV) of active, non-cancel lines.
    //    Compute expected via the same aggregate used by the class.
    // ------------------------------------------------------------------
    @IsTest
    static void test_afterUpdate_approved_createsPackages_andUpdatesInstallPrice() {
        TestDataFactory_OTG.enableOrgVRConfig();
        TestDataFactory_OTG.primeDefaultOwnerAllRegions(UserInfo.getUserId());

        TestDataFactory_OTG.QuoteContext ctx =
            TestDataFactory_OTG.buildDraftQuoteContext('Americas', false, false);

        // One user-created group
        SBQQ__QuoteLineGroup__c userGroup =
            TestDataFactory_OTG.createQuoteLineGroup(ctx.quote.Id, 'User QLG', false, 1);

        // Add lines: one Cancel (qty 0 with prior>0), one New
        addLine(ctx.quote.Id, userGroup.Id, ctx.pbe.Id, 0, 1, 10);  // Cancel (excluded in class aggregate)
        addLine(ctx.quote.Id, userGroup.Id, ctx.pbe.Id, 2, null, 50); // New/active

        Test.startTest();
        // Approve to trigger afterUpdate logic (syncPackageRecords + InstallationCostCalculation)
        update new SBQQ__Quote__c(Id = ctx.quote.Id, SBQQ__Status__c = 'Approved');
        Test.stopTest();

        // Compute expected via the same aggregate your class uses
        AggregateResult ar = [
            SELECT SUM(Annual_Subscription_Value__c) total
            FROM SBQQ__QuoteLine__c
            WHERE SBQQ__Group__c != NULL
              AND SBQQ__Group__c = :userGroup.Id
              AND SBQQ__StartDate__c <= :Date.today()
              AND SBQQ__EndDate__c   >= :Date.today()
              AND (Change_Type__c = NULL OR Change_Type__c != 'Cancel')
        ];
        Decimal expected = (Decimal) (ar.get('total') == null ? 0 : ar.get('total'));

        SBQQ__QuoteLineGroup__c gAfter = [
            SELECT Id, Package__c, Installation_Price__c
            FROM SBQQ__QuoteLineGroup__c
            WHERE Id = :userGroup.Id
        ];

        System.assertNotEquals(null, gAfter.Package__c, 'User-created QLG should have a new Package');
        System.assertEquals(expected.setScale(2), gAfter.Installation_Price__c.setScale(2),
            'Installation_Price__c must equal SUM(ASV) of active non-cancel lines');
    }
}