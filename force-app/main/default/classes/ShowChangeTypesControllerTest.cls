@IsTest
private class ShowChangeTypesControllerTest {

    @IsTest
    static void test_Defaults_Are_Applied_When_Null() {
        // Build a minimal draft quote context (factory handles org setup & owners)
        TestDataFactory_OTG.QuoteContext ctx =
            TestDataFactory_OTG.buildDraftQuoteContext('EMEA', false, false);

        // Create a user group with all three fields left NULL
        SBQQ__QuoteLineGroup__c gDefault =
            TestDataFactory_OTG.createQuoteLineGroup(ctx.quote.Id, 'Defaults Group', false, 1);
        // (No updates here—fields remain NULL)

        Test.startTest();
        List<SBQQ__QuoteLineGroup__c> result =
            ShowChangeTypesController.getQuoteLineGroups(ctx.quote.Id);
        Test.stopTest();

        // Find our group in the returned list
        SBQQ__QuoteLineGroup__c got = null;
        for (SBQQ__QuoteLineGroup__c g : result) {
            if (g.Id == gDefault.Id) { got = g; break; }
        }
        System.assertNotEquals(null, got, 'Expected Defaults Group to be returned');

        // Controller should default NULLs to "No Change" and 0
        System.assertEquals('No Change', got.Product_Change_Type__c,
            'Product_Change_Type__c should default to "No Change"');
        System.assertEquals('No Change', got.Installation_Change_Type__c,
            'Installation_Change_Type__c should default to "No Change"');
        System.assertEquals(0, got.Installation_Price__c,
            'Installation_Price__c should default to 0');
    }

    @IsTest
    static void test_NonNulls_Are_Not_Overwritten() {
        // Build a minimal draft quote context
        TestDataFactory_OTG.QuoteContext ctx =
            TestDataFactory_OTG.buildDraftQuoteContext('Americas', false, false);

        // Create a group and pre-populate all 3 fields
        SBQQ__QuoteLineGroup__c gPreset =
            TestDataFactory_OTG.createQuoteLineGroup(ctx.quote.Id, 'Preset Group', true, 1);

        update new SBQQ__QuoteLineGroup__c(
            Id                           = gPreset.Id,
            Product_Change_Type__c       = 'New Product Added',
            Installation_Change_Type__c  = 'Products Added & Removed',
            Installation_Price__c        = 123.45
        );

        Test.startTest();
        List<SBQQ__QuoteLineGroup__c> result =
            ShowChangeTypesController.getQuoteLineGroups(ctx.quote.Id);
        Test.stopTest();

        // Find our group in the returned list
        SBQQ__QuoteLineGroup__c got = null;
        for (SBQQ__QuoteLineGroup__c g : result) {
            if (g.Id == gPreset.Id) { got = g; break; }
        }
        System.assertNotEquals(null, got, 'Expected Preset Group to be returned');

        // Controller should NOT overwrite already-populated fields
        System.assertEquals('New Product Added', got.Product_Change_Type__c);
        System.assertEquals('Products Added & Removed', got.Installation_Change_Type__c);
        System.assertEquals(123.45, got.Installation_Price__c);
    }
}