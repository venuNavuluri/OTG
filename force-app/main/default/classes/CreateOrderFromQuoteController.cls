public with sharing class CreateOrderFromQuoteController
{
    private static final String INSTALLATION_COUNT_MISMATCH_TEMPLATE =
        '- <strong>{0}</strong>: {1} active installation(s), Installation Quantity {2}';
    private static final String INSTALLATION_COUNT_MISMATCH_PREFIX =
        'The following packages have installation quantity mismatches:\n';
    private static final String INSTALLATION_COUNT_MISMATCH_SUFFIX =
        '\n\nPlease update the package installations or package quantities before creating the order.';

    public static string updateQuoteToOrdered(String qtId)
    {
        return updateQuoteToOrdered(qtId, false);
    }

    @AuraEnabled
    public static string updateQuoteToOrdered(String qtId, Boolean requiresServiceOrder)
    {
        try
        {
            VRConfiguration__c vrConfig = VRConfiguration__c.getOrgDefaults();
            // Bypass validation by setting the custom setting field to true
            vrConfig.Quote_Ordered_Validation__c = true;
            upsert vrConfig; 
            
            System.debug('qtid --> ' + qtId);
            Boolean hasSowProducts = quoteHasSowProducts(qtId);
            SBQQ__Quote__c qt = new SBQQ__Quote__c(
                Id = qtId,
                SBQQ__Ordered__c = TRUE,
                Requires_Service_Order__c = requiresServiceOrder == true || hasSowProducts
 
            );
            update qt;
            System.debug('qt --> ' + qt);

            vrConfig.Quote_Ordered_Validation__c = false;
            upsert vrConfig; 
            //PDF generation logic
            
            //QuotePDFGenerator.PDFGenerate(new set<id>{qt.Id},'SBQQ__Quote__c');
            return 'SUCCESS';
        } catch (Exception ex) {
            System.debug('ex --> ' + ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
            throw new AuraHandledException(ex.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static String validateInstallationCount(String qtId)
    {
        SBQQ__Quote__c quote = [
            SELECT Id, SBQQ__Type__c
            FROM SBQQ__Quote__c
            WHERE Id = :qtId
            LIMIT 1
        ];
        Boolean isRenewal = quote.SBQQ__Type__c == 'Renewal';

        List<Package__c> packList;
        if (isRenewal) {
            packList = [
                SELECT Id, Name, Quote__c, Temp_Quote_Line_Group__r.Installation_Quantity__c, Installation_Quantity__c,
                    (SELECT Id, Name FROM Installations__r WHERE Installation_Order_Status__c != 'Terminated' AND Installation_Order_Status__c != 'Future Terminated' AND Installation_Order_Status__c != 'Termination Pending')
                FROM Package__c
                WHERE Temp_Quote__c = :qtId AND Temp_Quote_Line_Group__c != null
                ORDER BY CreatedDate DESC
            ];
        } else {
            packList = [
                SELECT Id, Name, Quote__c, Temp_Quote_Line_Group__r.Installation_Quantity__c, Installation_Quantity__c,
                    (SELECT Id, Name FROM Installations__r WHERE Installation_Order_Status__c != 'Terminated' AND Installation_Order_Status__c != 'Termination Pending')
                FROM Package__c
                WHERE Temp_Quote__c = :qtId AND Temp_Quote_Line_Group__c != null
                ORDER BY CreatedDate DESC
            ];
        }

        List<String> mismatchMessages = new List<String>();
        for (Package__c pack : packList) {
            Integer activeInstallations = (pack.Installations__r == null) ? 0 : pack.Installations__r.size();
            Decimal expectedQty = pack.Temp_Quote_Line_Group__r == null ? null : pack.Temp_Quote_Line_Group__r.Installation_Quantity__c;
            System.debug('validateInstallationCount pack ' + pack.Id + ' expectedQty=' + expectedQty + ' activeInstallations=' + activeInstallations);
            if (pack.Installations__r != null &&
                expectedQty != null &&
                expectedQty != activeInstallations) {
                System.debug('validateInstallationCount mismatch pack ' + pack.Id + ' expectedQty=' + expectedQty + ' activeInstallations=' + activeInstallations);
                mismatchMessages.add(String.format(
                    INSTALLATION_COUNT_MISMATCH_TEMPLATE,
                    new List<String>{
                        escapeHtml(pack.Name),
                        String.valueOf(activeInstallations),
                        String.valueOf(expectedQty)
                    }
                ));
            }
        }
        if (!mismatchMessages.isEmpty()) {
            return INSTALLATION_COUNT_MISMATCH_PREFIX +
                String.join(mismatchMessages, '\n') +
                INSTALLATION_COUNT_MISMATCH_SUFFIX;
        }
        return 'SUCCESS';
    }

    private static String escapeHtml(String value) {
        return String.isBlank(value) ? '' : value.escapeHtml4();
    }

    private static Boolean quoteHasSowProducts(String qtId) {
        if (String.isBlank(qtId)) {
            return false;
        }
        return [
            SELECT COUNT()
            FROM SBQQ__QuoteLine__c
            WHERE SBQQ__Quote__c = :qtId
              AND SBQQ__Product__r.Addendum_Requires_SOW__c = 'Yes'
        ] > 0;
    }
}
