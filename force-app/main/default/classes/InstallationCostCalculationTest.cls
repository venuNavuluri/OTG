@IsTest
private class InstallationCostCalculationTest {

    @IsTest
    static void test_ProductChangeType_Combinations() {
        // Minimal base context; no invoice/contact to keep limits low
        TestDataFactory_OTG.QuoteContext ctx =
            TestDataFactory_OTG.buildDraftQuoteContext('Americas', false, false);

        // Make it an Amendment so your Change_Type__c formula evaluates per spec
        ctx.quote.SBQQ__Type__c = 'Amendment';
        update ctx.quote;

        SBQQ__QuoteLineGroup__c g1 = ctx.groups[0]; // Cancel only
        SBQQ__QuoteLineGroup__c g2 = ctx.groups[1]; // New only
        SBQQ__QuoteLineGroup__c g3 = TestDataFactory_OTG.createQuoteLineGroup(ctx.quote.Id, 'G3', true, 1); // Both

        Date s = Date.today(), e = s.addMonths(12);

        // g1: Cancel only => qty=0, prior>0
        TestDataFactory_OTG.createQuoteLine(ctx.quote.Id, g1.Id, ctx.pbe.Id, 0, 2, 10, s, e, null);
        // g2: New only => prior null, qty>0
        TestDataFactory_OTG.createQuoteLine(ctx.quote.Id, g2.Id, ctx.pbe.Id, 1, null, 20, s, e, null);
        // g3: Cancel + New
        TestDataFactory_OTG.createQuoteLine(ctx.quote.Id, g3.Id, ctx.pbe.Id, 0, 1, 30, s, e, null);
        TestDataFactory_OTG.createQuoteLine(ctx.quote.Id, g3.Id, ctx.pbe.Id, 1, null, 40, s, e, null);

        Test.startTest();
        InstallationCostCalculation.updateInstallationPriceByQuotes(new Set<Id>{ ctx.quote.Id }, Date.today());
        Test.stopTest();

        Map<Id, SBQQ__QuoteLineGroup__c> groups =
            new Map<Id, SBQQ__QuoteLineGroup__c>([
                SELECT Id, Product_Change_Type__c, Installation_Price__c
                FROM SBQQ__QuoteLineGroup__c
                WHERE Id IN :new Set<Id>{ g1.Id, g2.Id, g3.Id }
            ]);

        System.assertEquals('Product Removed',            groups.get(g1.Id).Product_Change_Type__c);
        System.assertEquals('New Product Added',          groups.get(g2.Id).Product_Change_Type__c);
        System.assertEquals('Products Added & Removed',   groups.get(g3.Id).Product_Change_Type__c);

        // ASV is a formula in your org, so assert the behaviors, not hard numbers:
        System.assertEquals(0, groups.get(g1.Id).Installation_Price__c, 'Cancel-only should contribute 0');
        System.assert(       groups.get(g2.Id).Installation_Price__c > 0, 'New-only should be > 0');
        System.assert(       groups.get(g3.Id).Installation_Price__c > 0, 'Combo should be > 0 (from New)');
    }

    @IsTest
    static void test_NewPackage_Label_When_Group_Not_From_Package() {
        TestDataFactory_OTG.QuoteContext ctx =
            TestDataFactory_OTG.buildDraftQuoteContext('EMEA', false, false);

        // User-created group (Created_From_Package__c = false)
        SBQQ__QuoteLineGroup__c g = TestDataFactory_OTG.createQuoteLineGroup(ctx.quote.Id, 'User Group', false, 1);

        // Add a "New" line to make rollup non-zero
        Date s = Date.today(), e = s.addMonths(12);
        TestDataFactory_OTG.createQuoteLine(ctx.quote.Id, g.Id, ctx.pbe.Id, 1, null, 15, s, e, null);

        Test.startTest();
        InstallationCostCalculation.updateInstallationPriceByQuotes(new Set<Id>{ ctx.quote.Id }, Date.today());
        Test.stopTest();

        SBQQ__QuoteLineGroup__c reloaded = [
            SELECT Product_Change_Type__c, Installation_Price__c
            FROM SBQQ__QuoteLineGroup__c
            WHERE Id = :g.Id
            LIMIT 1
        ];
        System.assertEquals('New Package', reloaded.Product_Change_Type__c);
        System.assert(reloaded.Installation_Price__c > 0);
    }
}