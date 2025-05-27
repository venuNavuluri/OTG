public class ConvertToOpportunityController
{
    @AuraEnabled
    public static String convertToOpportunity(String recId)
    {
        List<Lead> ldList = [SELECT Id, Name, Account__c, Account__r.OwnerId, Contact__c, Campaign__c, Description, Products__c FROM Lead WHERE Id = :recId];
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
                
                String product = ldList[0].Products__c;
                String productGroup = '';
                String businessUnit = '';
                
                if (product != null)
                {
                    if (product.contains('Learning & Assessment'))
                    {
                        businessUnit = 'Learning & Assessment';
                    }
                    else if (product.contains('Fleet Management System (TM Master)'))
                    {
                        businessUnit = 'Fleet';
                        productGroup = 'TM Master';
                    }
                    else if (product.contains('Crew Management/HR System (Compas)'))
                    {
                        businessUnit = 'Crew';
                        productGroup = 'Compas Core';
                    }
                    else if (product.contains('Marine Regulations'))
                    {
                        businessUnit = 'Marine Regulations';
                        productGroup = 'Marine Regulations';
                    }
                }
                Database.LeadConvertResult lcr = Database.convertLead(lc); Opportunity opp = new Opportunity(
                    Id = lcr.getOpportunityId(), Contact_Name__c = ldList[0].Contact__c, CampaignId = ldList[0].Campaign__c, Description = ldList[0].Description, Contract_Term__c = '12', Product_Group__c = productGroup, Business_Unit__c = businessUnit
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