public class GenerateDocumentController
{
    @AuraEnabled
    public static string saveAsDocument(Id qtId)
    {
        try
        {
            String docName = '';
            String contId;
            Id recId = NULL;
            String title = '';
            String name = '';
            if(qtId.getSObjectType() == Schema.SBQQ__Quote__c.SObjectType)
            {
                docName = 'ContractDocumentPDF';
                recId = qtId;
                SBQQ__Quote__c qt = [SELECT Id, Name, SBQQ__Account__c, SBQQ__Account__r.Name, SBQQ__Opportunity2__r.Business_Unit__c FROM SBQQ__Quote__c WHERE Id = :qtId];
                title = 'RenewalQuote_' +  qt.Name + '-' + qt.SBQQ__Account__r.Name + '_' + qt.SBQQ__Opportunity2__r.Business_Unit__c;
            }
            else if(qtId.getSObjectType() == Schema.Contract.SObjectType)
            {
                docName = 'ContractOverviewDocPDF';
                contId = qtId;
                recId = contId;
                Contract contr = [SELECT Id, Name, ContractNumber, Account.Name, SBQQ__Quote__c FROM Contract WHERE Id = :contId];
                qtId = contr.SBQQ__Quote__c;
                title = contr.Account.Name + '-Contract Overview ';
                name = contr.ContractNumber;
            }
            PageReference pr = new PageReference('/apex/' + docName + '?id=' + recId);
            
            SBQQ__Quote__c qt = [SELECT Id, Name, SBQQ__Account__c, SBQQ__Account__r.Name FROM SBQQ__Quote__c WHERE Id = :qtId];
            name = name == '' ? qt.Name : name;
            
            List<ContentDocumentLink> cdlList = [SELECT ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId = :recId];
            System.debug('cdlList --> ' + cdlList);
            ContentVersion ContVerFileExist = new ContentVersion();
            if(cdlList != NULL && !cdlList.isEmpty())
            {
                //String totalTitle = title + qt.SBQQ__Account__r.Name + ' ' + name;
                ContVerFileExist = [SELECT Id, Title, VersionData, PathOnClient, ContentDocumentId FROM ContentVersion WHERE ContentDocumentId =: cdlList[0].ContentDocumentId AND Title LIKE: title + '%' ORDER BY CreatedDate DESC LIMIT 1];
                //ContVerFile.VersionData = Test.isRunningTest() ? Blob.valueOf('Test') : pr.getContentAsPDF();
                //update ContVerFile;
            }
            
            Date td = Date.today();
            ContentVersion ContVerFile = new ContentVersion();
            ContVerFile.VersionData = Test.isRunningTest() ? Blob.valueOf('Test') : pr.getContentAsPDF();
            ContVerFile.Title = recId.getSObjectType() == Schema.Contract.SObjectType ? title + td.day() + '_' + td.month() + '_' + td.year() : title; 
            ContVerFile.ContentLocation= 's';
            ContVerFile.PathOnClient = title + qt.SBQQ__Account__r.Name + ' ' + name + '.pdf';
            ContVerFile.ContentDocumentId = (cdlList != NULL && !cdlList.isEmpty() ? ContVerFileExist.ContentDocumentId : NULL);
            insert ContVerFile;
            
            if(cdlList == NULL || cdlList.isEmpty())
            {
                Id conDoc = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =:ContVerFile.Id].ContentDocumentId;
                ContentDocumentLink cDe = new ContentDocumentLink();
                cDe.ContentDocumentId = conDoc;
                cDe.LinkedEntityId = recId;
                cDe.ShareType = 'I';
                cDe.Visibility = 'AllUsers';
                upsert cDe;
            }
            
            return 'SUCCESS';
        }
        catch (Exception e)
        {
            System.debug('e --> ' + e.getMessage());
            System.debug('e --> ' + e.getLineNumber());
            System.debug('e --> ' + e);
            throw new AuraHandledException(e.getMessage());
        }
    }
}