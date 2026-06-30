public with sharing class ApproveQuoteController {
    public class QuoteApprovalPreview {
        @AuraEnabled public Id quoteId;
        @AuraEnabled public String quoteName;
        @AuraEnabled public String status;
        @AuraEnabled public Boolean ordered;
        @AuraEnabled public Boolean uncalculated;
        @AuraEnabled public Date effectiveDate;
        @AuraEnabled public Decimal totalAnnualSubscriptionValue;
        @AuraEnabled public String currencyIsoCode;
        @AuraEnabled public Boolean canApprove;
        @AuraEnabled public String blockingMessage;
        @AuraEnabled public List<InstallationCostCalculation.QuoteLineGroupCalculation> groups;
    }

    @AuraEnabled(cacheable=false)
    public static QuoteApprovalPreview previewApproval(Id quoteId) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }

        SBQQ__Quote__c quote = [
            SELECT Id, Name, CurrencyIsoCode, SBQQ__Status__c, SBQQ__Ordered__c, SBQQ__Uncalculated__c,
                   Total_Annual_Subscription_Value__c
            FROM SBQQ__Quote__c
            WHERE Id = :quoteId
            LIMIT 1
        ];

        QuoteApprovalPreview preview = new QuoteApprovalPreview();
        preview.quoteId = quote.Id;
        preview.quoteName = quote.Name;
        preview.status = quote.SBQQ__Status__c;
        preview.ordered = quote.SBQQ__Ordered__c;
        preview.uncalculated = quote.SBQQ__Uncalculated__c;
        preview.totalAnnualSubscriptionValue = quote.Total_Annual_Subscription_Value__c == null
            ? 0
            : quote.Total_Annual_Subscription_Value__c;
        preview.currencyIsoCode = quote.CurrencyIsoCode;
        preview.effectiveDate = InstallationCostCalculation.resolveEffectiveDate(quote.Id);
        preview.groups = InstallationCostCalculation.previewQuoteLineGroupInstallationCosts(quote.Id);
        preview.canApprove = true;

        if (quote.SBQQ__Status__c == 'Approved') {
            preview.canApprove = false;
            preview.blockingMessage = 'This Quote is already approved.';
        } else if (quote.SBQQ__Ordered__c == true) {
            preview.canApprove = false;
            preview.blockingMessage = 'This Quote is already ordered.';
        } else if (preview.groups == null || preview.groups.isEmpty()) {
            preview.canApprove = false;
            preview.blockingMessage = 'No Quote Line Groups were found to review.';
        }

        if (preview.canApprove && quote.SBQQ__Uncalculated__c == true) {
            preview.blockingMessage = 'This Quote is marked as uncalculated. Recalculate it if the quote lines were changed recently.';
        }

        return preview;
    }

    @AuraEnabled
    public static String approveQuote(Id quoteId) {
        QuoteApprovalPreview preview = previewApproval(quoteId);
        if (!preview.canApprove) {
            throw new AuraHandledException(preview.blockingMessage);
        }

        QuoteTriggerHandler.setApproveQuoteActionInProgress(true);
        try {
            update new SBQQ__Quote__c(
                Id = quoteId,
                SBQQ__Status__c = 'Approved'
            );
        } catch (DmlException ex) {
            throw new AuraHandledException(formatDmlException(ex));
        } catch (Exception ex) {
            throw new AuraHandledException(formatException(ex));
        } finally {
            QuoteTriggerHandler.setApproveQuoteActionInProgress(false);
        }

        return 'SUCCESS';
    }

    @TestVisible
    private static String formatDmlException(DmlException ex) {
        if (ex == null) {
            return 'The quote could not be approved. Please contact your Salesforce administrator.';
        }

        List<String> messages = new List<String>();
        for (Integer i = 0; i < ex.getNumDml(); i++) {
            String message = cleanErrorMessage(ex.getDmlMessage(i));
            List<String> fields = ex.getDmlFieldNames(i);
            if (fields != null && !fields.isEmpty()) {
                message += ' Field: ' + String.join(fields, ', ');
            }
            addUniqueMessage(messages, message);
        }

        if (messages.isEmpty()) {
            addUniqueMessage(messages, cleanErrorMessage(ex.getMessage()));
        }

        return 'The quote could not be approved. ' + String.join(messages, '\n');
    }

    @TestVisible
    private static String formatException(Exception ex) {
        String message = ex == null ? null : ex.getMessage();
        message = cleanErrorMessage(message);
        if (String.isBlank(message)) {
            message = 'Please contact your Salesforce administrator.';
        }
        return 'The quote could not be approved. ' + message;
    }

    private static void addUniqueMessage(List<String> messages, String message) {
        if (String.isBlank(message) || messages.contains(message)) {
            return;
        }
        messages.add(message);
    }

    private static String cleanErrorMessage(String message) {
        if (String.isBlank(message)) {
            return '';
        }

        String cleaned = message;
        cleaned = cleaned.replace('FIELD_CUSTOM_VALIDATION_EXCEPTION,', '');
        cleaned = cleaned.replace('CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY,', '');
        cleaned = cleaned.replace('REQUIRED_FIELD_MISSING,', '');
        cleaned = cleaned.replace('INVALID_FIELD_FOR_INSERT_UPDATE,', '');
        cleaned = cleaned.replace('INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST,', '');
        cleaned = cleaned.replace(': []', '');

        Integer firstColon = cleaned.indexOf(':');
        if (firstColon > -1 && cleaned.left(firstColon).contains('_EXCEPTION')) {
            cleaned = cleaned.substring(firstColon + 1);
        }

        while (cleaned.contains('  ')) {
            cleaned = cleaned.replace('  ', ' ');
        }

        return cleaned.trim();
    }
}
