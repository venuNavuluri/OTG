public with sharing class CreateOrderFromQuoteController
{
    @AuraEnabled
    public static string updateQuoteToOrdered(String qtId)
    {
        Automation_Bypass_Settings__c userBypassSettings = Automation_Bypass_Settings__c.getInstance(UserInfo.getUserId());
        if (userBypassSettings == null) {
            userBypassSettings = new Automation_Bypass_Settings__c(SetupOwnerId = UserInfo.getUserId());
        }
        Boolean previousBypassValidations = userBypassSettings.Bypass_Validations__c;

        try
        {
            userBypassSettings.Bypass_Validations__c = true;
            upsert userBypassSettings;
            
            System.debug('qtid --> ' + qtId);
            SBQQ__Quote__c qt = new SBQQ__Quote__c(
                Id = qtId,
                SBQQ__Ordered__c = TRUE
 
            );
            update qt;
            System.debug('qt --> ' + qt);
            //PDF generation logic
            
            //QuotePDFGenerator.PDFGenerate(new set<id>{qt.Id},'SBQQ__Quote__c');
            return 'SUCCESS';
        } catch (Exception ex) {
            System.debug('ex --> ' + ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
            throw new AuraHandledException(ex.getMessage());
        } finally {
            userBypassSettings.Bypass_Validations__c = previousBypassValidations;
            upsert userBypassSettings;
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
                    (SELECT Id, Name FROM Installations__r WHERE Installation_Order_Status__c != 'Terminated' AND Installation_Order_Status__c != 'Future Terminated')
                FROM Package__c
                WHERE Temp_Quote__c = :qtId AND Temp_Quote_Line_Group__c != null
                ORDER BY CreatedDate DESC
            ];
        } else {
            packList = [
                SELECT Id, Name, Quote__c, Temp_Quote_Line_Group__r.Installation_Quantity__c, Installation_Quantity__c,
                    (SELECT Id, Name FROM Installations__r WHERE Installation_Order_Status__c != 'Terminated')
                FROM Package__c
                WHERE Temp_Quote__c = :qtId AND Temp_Quote_Line_Group__c != null
                ORDER BY CreatedDate DESC
            ];
        }

        for (Package__c pack : packList) {
            Integer activeInstallations = (pack.Installations__r == null) ? 0 : pack.Installations__r.size();
            Decimal expectedQty = pack.Temp_Quote_Line_Group__r == null ? null : pack.Temp_Quote_Line_Group__r.Installation_Quantity__c;
            System.debug('validateInstallationCount pack ' + pack.Id + ' expectedQty=' + expectedQty + ' activeInstallations=' + activeInstallations);
            if (pack.Installations__r != null &&
                expectedQty != null &&
                expectedQty != activeInstallations) {
                System.debug('validateInstallationCount mismatch pack ' + pack.Id + ' expectedQty=' + expectedQty + ' activeInstallations=' + activeInstallations);
                return 'No. of active installations on package must match with the Installation Quantity on package';
            }
        }
        return 'SUCCESS';
    }
}