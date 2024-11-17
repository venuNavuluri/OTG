public class RelatedLeadsController {
    @AuraEnabled(cacheable=true)
    public static List<Lead> getRelatedLeads(Id recordId) {
        List<Lead> relatedLeads = new List<Lead>();
        
        // Fetch Leads related to the Account or Contact
        relatedLeads.addAll([
            SELECT Id, Name, Status, Lead_ID__c, Lead_Progress_Comments__c, Description, LeadSource, Products__c, Account__c, Contact__c, ConvertedDate, IsConverted, ConvertedAccountId, ConvertedContactId, ConvertedOpportunityId
            FROM Lead
            WHERE (Account__c = :recordId OR Contact__c = :recordId)
            AND (IsConverted = TRUE OR IsConverted = FALSE)
        ]);
        
        // Log the results to debug
        System.debug('Related Leads: ' + relatedLeads);
        
        return relatedLeads;
    } 
}