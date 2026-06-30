@IsTest
private class ApproveQuoteControllerTest {
    @IsTest
    static void testPreviewDoesNotPersistCalculatedValues() {
        TestDataFactory_OTG.QuoteContext ctx =
            TestDataFactory_OTG.buildDraftQuoteContext('Americas', false, false);

        SBQQ__QuoteLineGroup__c qlg =
            TestDataFactory_OTG.createQuoteLineGroup(ctx.quote.Id, 'Preview Group', false, 1);
        Date startDate = Date.today();
        TestDataFactory_OTG.createQuoteLine(ctx.quote.Id, qlg.Id, ctx.pbe.Id, 2, null, 50, startDate, startDate.addMonths(12), null);

        Test.startTest();
        ApproveQuoteController.QuoteApprovalPreview preview = ApproveQuoteController.previewApproval(ctx.quote.Id);
        Test.stopTest();

        System.assertEquals(true, preview.canApprove, 'Draft calculated quote should be approvable');
        System.assert(!preview.groups.isEmpty(), 'Preview should return quote line groups');

        InstallationCostCalculation.QuoteLineGroupCalculation target;
        for (InstallationCostCalculation.QuoteLineGroupCalculation row : preview.groups) {
            if (row.quoteLineGroupId == qlg.Id) {
                target = row;
            }
        }
        System.assertNotEquals(null, target, 'Preview should include the test group');
        System.assert(target.installationPrice > 0, 'Preview should calculate an installation price');

        SBQQ__QuoteLineGroup__c afterPreview = [
            SELECT Installation_Price__c
            FROM SBQQ__QuoteLineGroup__c
            WHERE Id = :qlg.Id
        ];
        System.assertEquals(null, afterPreview.Installation_Price__c, 'Preview must not persist installation price');
    }

    @IsTest
    static void testApproveQuoteUpdatesStatusAndPersistsCalculatedValues() {
        TestDataFactory_OTG.enableOrgVRConfig();
        TestDataFactory_OTG.primeDefaultOwnerAllRegions(UserInfo.getUserId());

        TestDataFactory_OTG.QuoteContext ctx =
            TestDataFactory_OTG.buildDraftQuoteContext('Americas', false, false);

        SBQQ__QuoteLineGroup__c qlg =
            TestDataFactory_OTG.createQuoteLineGroup(ctx.quote.Id, 'Approve Group', false, 1);
        Date startDate = Date.today();
        TestDataFactory_OTG.createQuoteLine(ctx.quote.Id, qlg.Id, ctx.pbe.Id, 1, null, 75, startDate, startDate.addMonths(12), null);

        Test.startTest();
        String result = ApproveQuoteController.approveQuote(ctx.quote.Id);
        Test.stopTest();

        System.assertEquals('SUCCESS', result);

        SBQQ__Quote__c quoteAfter = [
            SELECT SBQQ__Status__c
            FROM SBQQ__Quote__c
            WHERE Id = :ctx.quote.Id
        ];
        System.assertEquals('Approved', quoteAfter.SBQQ__Status__c);

        SBQQ__QuoteLineGroup__c groupAfter = [
            SELECT Installation_Price__c, Product_Change_Type__c
            FROM SBQQ__QuoteLineGroup__c
            WHERE Id = :qlg.Id
        ];
        System.assert(groupAfter.Installation_Price__c > 0, 'Approval should persist calculated installation price');
        System.assertEquals('New Package', groupAfter.Product_Change_Type__c);
    }

    @IsTest
    static void testPreviewBlocksAlreadyApprovedQuote() {
        TestDataFactory_OTG.QuoteContext ctx =
            TestDataFactory_OTG.buildDraftQuoteContext('EMEA', false, false);

        QuoteTriggerHandler.setApproveQuoteActionInProgress(true);
        try {
            update new SBQQ__Quote__c(
                Id = ctx.quote.Id,
                SBQQ__Status__c = 'Approved'
            );
        } finally {
            QuoteTriggerHandler.setApproveQuoteActionInProgress(false);
        }

        Test.startTest();
        ApproveQuoteController.QuoteApprovalPreview preview = ApproveQuoteController.previewApproval(ctx.quote.Id);
        Test.stopTest();

        System.assertEquals(false, preview.canApprove);
        System.assertEquals('This Quote is already approved.', preview.blockingMessage);
    }

    @IsTest
    static void testManualStatusChangeToApprovedIsBlocked() {
        TestDataFactory_OTG.QuoteContext ctx =
            TestDataFactory_OTG.buildDraftQuoteContext('EMEA', false, false);

        QuoteTriggerHandler.setEnforceApproveQuoteActionInTests(true);
        Test.startTest();
        Database.SaveResult result = Database.update(
            new SBQQ__Quote__c(
                Id = ctx.quote.Id,
                SBQQ__Status__c = 'Approved'
            ),
            false
        );
        Test.stopTest();
        QuoteTriggerHandler.setEnforceApproveQuoteActionInTests(false);

        System.assertEquals(false, result.isSuccess(), 'Manual approval should be blocked');
        System.assert(result.getErrors()[0].getMessage().contains('Use the Approve Quote button'));
    }

    @IsTest
    static void testAutoTerminationApprovalDecisionIsAllowed() {
        SBQQ__Quote__c updatedQuote = new SBQQ__Quote__c(
            SBQQ__Status__c = 'Approved',
            SBQQ__Ordered__c = true,
            SBQQ__Type__c = 'Amendment',
            Auto_Termination__c = true,
            Auto_Installation__c = false
        );
        SBQQ__Quote__c oldQuote = new SBQQ__Quote__c(
            SBQQ__Status__c = 'Draft'
        );
        SBQQ__Quote__c persistedQuote = new SBQQ__Quote__c();

        System.assertEquals(
            true,
            QuoteTriggerHandler.isAutoApprovalAndOrderUpdate(updatedQuote, oldQuote, persistedQuote),
            'Auto termination amendment quotes should be allowed through the approval guard.'
        );
    }

    @IsTest
    static void testApprovedQuoteCanMoveBackToDraft() {
        TestDataFactory_OTG.QuoteContext ctx =
            TestDataFactory_OTG.buildDraftQuoteContext('EMEA', false, false);

        QuoteTriggerHandler.setEnforceApproveQuoteActionInTests(true);
        QuoteTriggerHandler.setApproveQuoteActionInProgress(true);
        try {
            update new SBQQ__Quote__c(
                Id = ctx.quote.Id,
                SBQQ__Status__c = 'Approved'
            );
        } finally {
            QuoteTriggerHandler.setApproveQuoteActionInProgress(false);
        }

        Test.startTest();
        update new SBQQ__Quote__c(
            Id = ctx.quote.Id,
            SBQQ__Status__c = 'Draft'
        );
        Test.stopTest();
        QuoteTriggerHandler.setEnforceApproveQuoteActionInTests(false);

        SBQQ__Quote__c quoteAfter = [
            SELECT SBQQ__Status__c
            FROM SBQQ__Quote__c
            WHERE Id = :ctx.quote.Id
        ];
        System.assertEquals('Draft', quoteAfter.SBQQ__Status__c);
    }

    @IsTest
    static void testDmlErrorFormattingReturnsReadableMessage() {
        DmlException caughtException;
        try {
            insert new Account();
        } catch (DmlException ex) {
            caughtException = ex;
        }

        System.assertNotEquals(null, caughtException, 'Expected a DML exception for missing required fields.');

        String message = ApproveQuoteController.formatDmlException(caughtException);

        System.assert(message.startsWith('The quote could not be approved.'), 'Expected user-facing approval context.');
        System.assert(!message.contains('REQUIRED_FIELD_MISSING,'), 'Expected raw Salesforce error prefix to be removed.');
        System.assert(message.contains('Name'), 'Expected the actionable validation detail to remain.');
    }

    @IsTest
    static void testGenericErrorFormattingReturnsReadableMessage() {
        Exception caughtException;
        try {
            Integer value = 1 / 0;
            System.debug(value);
        } catch (Exception ex) {
            caughtException = ex;
        }

        String message = ApproveQuoteController.formatException(caughtException);

        System.assert(message.startsWith('The quote could not be approved.'), 'Expected user-facing approval context.');
        System.assert(message.length() > 'The quote could not be approved. '.length(), 'Expected the original error detail.');
    }
}
