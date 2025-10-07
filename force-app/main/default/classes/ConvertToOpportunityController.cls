public class ConvertToOpportunityController {
    @AuraEnabled
    public static String convertToOpportunity(String recId) {
        System.debug('Starting convertToOpportunity with recId: ' + recId);
        
        try {
            System.debug('Querying Lead with ID: ' + recId);
            List<Lead> ldList = [SELECT Id, Name, Account__c, Account__r.OwnerId, Contact__c, 
                                 Campaign__c, Description, Products__c, Business_Units__c, Pillar_Engagement_at_Qualification_actua__c,
                                 Account__r.Country__r.Sales_Region__c, Account__r.LROO_Product_Acc_Owner__c, Account__r.OTG_Product_Acc_Owner__c
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
                
                User oppOwner;
                
                if (ldList[0].Products__c != null)
                {
                    //Determine Opportunity Ownership
                    if (ldList[0].Products__c.contains('ISF Watchkeeper'))
                    {
                        oppOwner = [select Id from User where UserRole.Name = 'Watchkeeper Sales Director' limit 1];
                    }
                    else if (ldList[0].Products__c.contains('Cloud Fleet Manager'))
                    {
                        if (ldList[0].Account__r.Country__r.Sales_Region__c == 'APAC')
                        {
                            oppOwner = [select Id from User where UserRole.Name = 'CFM Sales APAC' limit 1];
                        }
                        else
                        {
                            oppOwner = [select Id from User where UserRole.Name = 'CFM Sales EMEAA' limit 1];
                        }
                    }
                    else if (ldList[0].Products__c.contains('Risk Manager') || ldList[0].Business_Units__c.contains('Voyage Performance & Optimization'))
                    {
                        oppOwner = [select Id from User where UserRole.Name = 'VPO Sales' limit 1];
                    }
                    else if (ldList[0].Products__c.contains('Regs4ships') || ldList[0].Products__c.contains('Docmap') || ldList[0].Business_Units__c.contains('Voyage Management'))
                    {
                        oppOwner = [select Id from User where Id = :ldList[0].Account__r.LROO_Product_Acc_Owner__c];
                    }
                    else if (ldList[0].Products__c.contains('MarineRegulations') || ldList[0].Products__c.contains('Marine Regulations') || ldList[0].Products__c.contains('TM Master') || ldList[0].Business_Units__c.contains('HCM Crew') || ldList[0].Business_Units__c.contains('HCM Learning, Assessment and Competency'))
                    {
                        oppOwner = [select Id from User where Id = :ldList[0].Account__r.OTG_Product_Acc_Owner__c];
                    }
                }
                
                lc.setAccountId(ldList[0].Account__c);
                lc.setContactId(ldList[0].Contact__c);
                
                User accOwner = [select Id, Profile.Name from User where Id = :ldList[0].Account__r.OwnerId];
                if (accOwner.Profile.Name != 'Identity User')
                {
                    lc.setOwnerId(ldList[0].Account__r.OwnerId);
                }
                
                System.debug('Set AccountId: ' + ldList[0].Account__c + 
                             ', ContactId: ' + ldList[0].Contact__c + 
                             ', OwnerId: ' + ldList[0].Account__r.OwnerId);
                
                String businessUnit = ldList[0].Business_Units__c;
                String productGroup = '';
                System.debug('Business Unit from Lead: ' + businessUnit);
                
                // Determine product group based on business unit
                if (businessUnit != null) {
                    System.debug('Determining Product Group based on Business Unit');
                    if (ldList[0].Products__c.contains('TM Master'))//(businessUnit == 'Technical Ship Management') 
                    {
                        productGroup = 'TM Master';
                    } 
                    else if (ldList[0].Products__c.contains('COMPAS'))//if (businessUnit == 'HCM Crew') 
                    {
                        productGroup = 'Compas Core';
                    } 
                    else if (ldList[0].Products__c.contains('ISF Watchkeeper'))
                    {
                        productGroup = 'ISF Watchkeeper';
                    }
                    else if (ldList[0].Products__c.contains('Cloud Fleet Manager'))
                    {
                        productGroup = 'Cloud Fleet Manager';
                    }
                    else if (ldList[0].Products__c.contains('Risk Manager'))
                    {
                        productGroup = 'Risk Manager';
                    }
                    else if (ldList[0].Products__c.contains('Regs4ships'))
                    {
                        productGroup = 'Regs4Ships';
                    }
                    else if (ldList[0].Products__c.contains('Docmap'))
                    {
                        productGroup = 'Docmap';
                    }
                    else if (ldList[0].Products__c.contains('Marine Regulations') || ldList[0].Products__c.contains('MarineRegulations'))//(businessUnit == 'Governance, Risk & Compliance') 
                    {
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
                    Business_Unit__c = businessUnit,
                    Contract_Type__c = 'New Contract' 
                );
                if (oppOwner != null)
                {
                    opp.OwnerId = oppOwner.Id;
                }
                else
                {
                    opp.OwnerId = ldList[0].Account__r.OwnerId;
                }
                
                update opp;
                
                
                System.debug('Preparing Opportunity update with values: ' + opp);
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
    
    @AuraEnabled
    public static List<Contract> getActivatedContracts(String opportunityId) {
        try {
            Opportunity opp = [SELECT Id, AccountId, Business_Unit__c, Existing_Opportunity_Type__c 
                               FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
            
            if (opp.Existing_Opportunity_Type__c == 'Up-Sell') {
                return [SELECT Id, ContractNumber, Contract_Flow_Label__c, Status, Business_Unit__c 
                        FROM Contract 
                        WHERE AccountId = :opp.AccountId 
                        AND Status = 'Activated'
                        AND Business_Unit__c = :opp.Business_Unit__c];
            }
            return new List<Contract>();
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching contracts: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void updateOpportunityWithContract(String opportunityId, String contractId) {
        try {            
            Opportunity opp = new Opportunity(
                Id = opportunityId,
                Amend_Contract_Sales__c = contractId,
                Contract_Type__c = 'Existing Contract' 
            );
            update opp;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating opportunity: ' + e.getMessage());
        }
    }
}