public class CreateLeadController
{
    public Boolean showComments{get; set;}
    public String comments{get; set;}
    
    public CreateLeadController()
    {
        showComments = TRUE;
    }
    
    public PageReference createLead() {
        String email = ApexPages.currentPage().getParameters().get('email');
        String campaignId = ApexPages.currentPage().getParameters().get('campaignId');
        
        List<Contact> conList = new List<Contact>();
        
        ID marketingQueueId = [SELECT id FROM Group WHERE Type = 'Queue' and DeveloperNAME = 'MarketingCampaign'].Id;

        Lead ld = new Lead();
        ld.LastName = 'Campaign Response';
        ld.Email = email;
        ld.Campaign__c = campaignId;
        ld.Company = 'Campaign Response';
        ld.LeadSource = 'Marketing Campaign';
        ld.Description = 'Campaign Response: ' + comments;

        if(email != '' && email != NULL)
        {
            conList = [SELECT Id, Name, FirstName, LastName, Phone, Account.Name, MobilePhone, AccountId FROM Contact WHERE Email = :email];
        }
        if (!conList.isEmpty()) {
            ld.Account__c = conList[0].AccountId;
            ld.Contact__c = conList[0].Id;
            ld.FirstName = conList[0].FirstName;
            ld.LastName = conList[0].LastName;
            ld.Phone = conList[0].Phone;
            ld.MobilePhone = conList[0].MobilePhone;
            ld.Company = conList[0].Account.Name;
            if (marketingQueueId != NULL) {
                ld.OwnerId = marketingQueueId;
            }
        }
        
        insert ld;
        showComments = FALSE;
        return null;
    }
}