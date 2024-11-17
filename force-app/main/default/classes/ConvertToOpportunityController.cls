public class ConvertToOpportunityController
{
    @AuraEnabled
    public static String convertToOpportunity(String recId)
    {
        List<Lead> ldList = [SELECT Id, Name, Account__c, Account__r.OwnerId, Contact__c, Campaign__c FROM Lead WHERE Id = :recId];
        if(ldList[0].Account__c != NULL && ldList[0].Contact__c != NULL)
        {
            try
            {
                
                Database.LeadConvert lc = new Database.LeadConvert();
                lc.setLeadId(ldList[0].Id);
                
                LeadStatus convertStatus = [SELECT Id, MasterLabel FROM LeadStatus WHERE IsConverted=true LIMIT 1];
                lc.setConvertedStatus(convertStatus.MasterLabel);
                
                lc.setAccountId(ldList[0].Account__c);
                lc.setContactId(ldList[0].Contact__c);
                lc.setOwnerId(ldList[0].Account__r.OwnerId);
                Database.LeadConvertResult lcr = Database.convertLead(lc); 
                Opportunity opp = new Opportunity(
                    Id = lcr.getOpportunityId(),
                    Contact_Name__c = ldList[0].Contact__c,
                    CampaignId = ldList[0].Campaign__c
                );
                update opp;
                system.debug('Opp Update   '+ opp );
                return lcr.getOpportunityId();
            }
            catch(Exception ex)
            {
                System.debug('ex --> ' + ex);
                return Label.Error_Message_Convert_Opportunity + ex.getMessage();
            }
        }
        else
        {
            return 'Error';
        }
    }
}