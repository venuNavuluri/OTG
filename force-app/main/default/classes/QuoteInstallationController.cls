public class QuoteInstallationController {
    
    @AuraEnabled
    public static string fetchQuoteLineGroups(String quoteId){
        try {
            List<SBQQ__QuoteLineGroup__c> quoteGroups = [Select Id,Name,Installation_Quantity__c,
                                                        SBQQ__Quote__r.SBQQ__Account__c,
                                                        (Select Id,Name,Installation_Type__c,Vessel_Name__c,Vessel_Name__r.Name,Organisation_Name__c,Organisation_Name__r.Name,
                                                        Invoice_Account__c,Invoice_Account__r.Name,Client__c,Client__r.Name,Delivery_Contact__c,Delivery_Contact__r.Name
                                                        FROM Installations__r),
                                                        (Select Id,Name,SBQQ__ProductName__c,SBQQ__Product__r.ProductCode
                                                        From SBQQ__LineItems__r)
                                                        From SBQQ__QuoteLineGroup__c
                                                        Where SBQQ__Quote__c =:quoteId Order By Name Asc];
            return JSON.serialize(quoteGroups);                                                    
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    @AuraEnabled
    public static String fetchQuoteLineGroupProducts(String quoteGrpId){
        try {
            Set<String> prodsList = new Set<String>();
            List<SBQQ__QuoteLine__c> quoteLines = [Select Id,Name,SBQQ__ProductName__c,SBQQ__Product__r.ProductCode
                                                    From SBQQ__QuoteLine__c
                                                    Where SBQQ__Group__c =:quoteGrpId Order By SBQQ__ProductName__c Asc];
            for(SBQQ__QuoteLine__c qline:quoteLines){
                prodsList.add(qline.SBQQ__Product__r.ProductCode+' : '+qline.SBQQ__ProductName__c);
            }
            String prodString = '';
            if(!prodsList.isEmpty()){
                prodString = String.join(new List<String>(prodsList),',');
            }
            return prodString;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    @AuraEnabled
    public static List<sObject> saveInstallation(List<sObject> sobjList){
        try {
            insert sobjList;
            return [Select Id,Name,Installation_Type__c,Vessel_Name__c,Vessel_Name__r.Name,Organisation_Name__c,Organisation_Name__r.Name,
            Invoice_Account__c,Invoice_Account__r.Name,Client__c,Client__r.Name,Delivery_Contact__c,Delivery_Contact__r.Name From Installation__c Where Id IN:sobjList];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}