public with sharing class CreateOrderFromQuoteController
{
    @AuraEnabled
    public static string updateQuoteToOrdered(String qtId)
    {
        try
        {
            VRConfiguration__c vrConfig = VRConfiguration__c.getOrgDefaults();
            // Bypass validation by setting the custom setting field to true
            vrConfig.Quote_Ordered_Validation__c = true;
            upsert vrConfig; 
            
            System.debug('qtid --> ' + qtId);
            SBQQ__Quote__c qt = new SBQQ__Quote__c(
                Id = qtId,
                SBQQ__Ordered__c = TRUE
 
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
        List<Package__c> packList = [SELECT Id, Name, Quote__c, Temp_Quote_Line_Group__r.Installation_Quantity__c, Installation_Quantity__c, (SELECT Id, Name FROM Installations__r WHERE Installation_Order_Status__c != 'Terminated') CreatedDate FROM Package__c WHERE Temp_Quote__c = :qtId ORDER BY CreatedDate DESC];
        for(Package__c pack : packList)
        {
            if((pack.Installations__r != NULL) && (pack.Temp_Quote_Line_Group__r.Installation_Quantity__c != pack.Installations__r.size()))
            {
                System.debug('In If');
                return 'No. of active installations on package must match with the Installation Quantity on package';
            }
        }
        return 'SUCCESS';
    }
}