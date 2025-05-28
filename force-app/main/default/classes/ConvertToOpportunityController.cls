public class ConvertToOpportunityController {
    @AuraEnabled
    public static String convertToOpportunity(String recId) {
        System.debug('Starting convertToOpportunity with recId: ' + recId);
        
        try {
            System.debug('Querying Lead with ID: ' + recId);
            List<Lead> ldList = [SELECT Id, Name, Account__c, Account__r.OwnerId, Contact__c, 
                                Campaign__c, Description, Products__c, Business_Units__c 
                                FROM Lead WHERE Id = :recId];
            
            System.debug('Found Lead record: ' + ldList);
            
            if(ldList.isEmpty()) {
                System.debug('No Lead found with ID: ' + recId);
                return 'Error: No Lead found';
            }
            
            if(ldList[0].Account__c != NULL && ldList[0].Contact__c != NULL) {
                System.debug('Lead has valid Account and Contact references');
                
                Database.LeadConvert lc = new Database.LeadConvert();
                lc.setLeadId(ldList[0].Id);
                System.debug('LeadConvert initialized for Lead ID: ' + ldList[0].Id);
                
                System.debug('Querying converted Lead status');
                LeadStatus convertStatus = [SELECT Id, MasterLabel FROM LeadStatus WHERE IsConverted=true LIMIT 1];
                lc.setConvertedStatus(convertStatus.MasterLabel);
                System.debug('Set converted status to: ' + convertStatus.MasterLabel);
                
                lc.setAccountId(ldList[0].Account__c);
                lc.setContactId(ldList[0].Contact__c);
                lc.setOwnerId(ldList[0].Account__r.OwnerId);
                System.debug('Set AccountId: ' + ldList[0].Account__c + 
                            ', ContactId: ' + ldList[0].Contact__c + 
                            ', OwnerId: ' + ldList[0].Account__r.OwnerId);
                
                String businessUnit = ldList[0].Business_Units__c;
                String productGroup = '';
                System.debug('Business Unit from Lead: ' + businessUnit);
                
                // Determine product group based on business unit
                if (businessUnit != null) {
                    System.debug('Determining Product Group based on Business Unit');
                    if (businessUnit == 'Fleet') {
                        productGroup = 'TM Master';
                    } 
                    else if (businessUnit == 'Crew') {
                        productGroup = 'Compas Core';
                    } 
                    else if (businessUnit == 'Marine Regulations') {
                        productGroup = 'Marine Regulations';
                    }
                    System.debug('Determined Product Group: ' + productGroup);
                } else {
                    System.debug('Business Unit is null, Product Group will remain empty');
                }
                
                System.debug('Attempting lead conversion');
                Database.LeadConvertResult lcr = Database.convertLead(lc); 
                System.debug('Lead conversion result: ' + lcr);
                System.debug('Converted Opportunity ID: ' + lcr.getOpportunityId());
                
                // Update opportunity with additional fields
                Opportunity opp = new Opportunity(
                    Id = lcr.getOpportunityId(), 
                    Contact_Name__c = ldList[0].Contact__c, 
                    CampaignId = ldList[0].Campaign__c, 
                    Description = ldList[0].Description, 
                    Contract_Term__c = '12',
                    Product_Group__c = productGroup,
                    Business_Unit__c = businessUnit
                );
                
                System.debug('Preparing Opportunity update with values: ' + opp);
                update opp;
                System.debug('Opportunity successfully updated: ' + opp);
                
                return lcr.getOpportunityId();
            }
            else {
                String errorMsg = 'Error: Missing Account or Contact reference. Account: ' + 
                                ldList[0].Account__c + ', Contact: ' + ldList[0].Contact__c;
                System.debug(errorMsg);
                return errorMsg;
            }
        }
        catch(Exception ex) {
            System.debug('Exception occurred: ' + ex.getMessage());
            System.debug('Stack trace: ' + ex.getStackTraceString());
            return Label.Error_Message_Convert_Opportunity + ex.getMessage();
        }
    }
}