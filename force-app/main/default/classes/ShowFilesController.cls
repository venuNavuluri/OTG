public class ShowFilesController
{
    public class FileObjWrap
    {
        @AuraEnabled
        public String objName;
        @AuraEnabled
        public List<FileWrap> fileList;
    }
    public class FileWrap
    {
        @AuraEnabled
        public String Title;
        @AuraEnabled
        public String docId;
        @AuraEnabled
        public String url;
        @AuraEnabled
        public String fileType;
        @AuraEnabled
        public Integer fileSize;
        @AuraEnabled
        public Date fileDate;
        public FileWrap(String titleName, String documentId, String type, Integer size, Date dt)
        {
            fileType = type;
            fileSize = size;
            fileDate = dt;
            Title = titleName;
            docId = documentId;
            url = System.URL.getSalesforceBaseURL().toExternalForm() + '/' + documentId;
        }
    }

    @AuraEnabled
    public static List<FileObjWrap> getFiles(String recId)
    {
        Id recordId = Id.valueOf(recId);
        String objName = recordId.getSObjectType().getDescribe().getName();
        System.debug('recordId --> ' + recordId.getSObjectType().getDescribe().getName());
        List<Id> parentIdList = new List<Id>();
        Id accId;
        if(objName == 'Opportunity')
        {
            accId = [SELECT Id, Name, AccountId FROM Opportunity WHERE Id = :recordId].AccountId;
        }
        else if(objName == 'Contract')
        {
            accId = [SELECT Id, Name, AccountId FROM Contract WHERE Id = :recordId].AccountId;
        }
        else if(objName == 'Account')
        {
            accId = recordId;
        }
        parentIdList.add(accId);
        System.debug('accId --> ' + accId);
        List<Opportunity> oppList = [SELECT Id, Name, AccountId FROM Opportunity WHERE AccountId = :accId];
        for(Opportunity opp : oppList)
        {
            parentIdList.add(opp.Id);
        }
        List<Contract> contrList = [SELECT Id, Name, AccountId FROM Contract WHERE AccountId = :accId];
        for(Contract contr : contrList)
        {
            parentIdList.add(contr.Id);
        }
        List<FileWrap> fileList = new List<FileWrap>();
        List<FileObjWrap> fileObjList = new List<FileObjWrap>();
        Map<Id, Id> mapCntIdParentId = new Map<Id, Id>();
        Map<Id, String> conDocIdObjNameMap = new Map<Id, String>();
        Map<String, List<FileWrap>> objFileWrapListMap = new Map<String, List<FileWrap>>();
        for(ContentDocumentLink cntLink : [Select Id, ContentDocumentId, LinkedEntityId From ContentDocumentLink Where LinkedEntityId IN :parentIdList])
        {
            mapCntIdParentId.put(cntLink.ContentDocumentId, cntLink.LinkedEntityId);
            conDocIdObjNameMap.put(cntLink.ContentDocumentId, cntLink.LinkedEntityId.getSObjectType().getDescribe().getName());
        }
        System.debug('conDocIdObjNameMap --> ' + conDocIdObjNameMap);
        if(!mapCntIdParentId.isEmpty())
        {
            for(ContentVersion cv :  [SELECT Id, Title, VersionData, ContentSize, FileExtension, FileType, ContentModifiedDate, ContentDocumentId FROM ContentVersion WHERE ContentDocumentId IN :mapCntIdParentId.keySet() AND IsLatest = True])
            {
                if(objFileWrapListMap.get(conDocIdObjNameMap.get(cv.ContentDocumentId)) == NULL)
                {
                    System.debug('docId --> ' + cv.ContentDocumentId);
                    objFileWrapListMap.put(conDocIdObjNameMap.get(cv.ContentDocumentId), new List<FileWrap>());
                }
                System.debug('id --> ' + conDocIdObjNameMap.get(cv.ContentDocumentId));
                objFileWrapListMap.get(conDocIdObjNameMap.get(cv.ContentDocumentId)).add(new FileWrap(cv.Title, cv.ContentDocumentId, cv.FileExtension, cv.ContentSize, Date.valueOf(cv.ContentModifiedDate)));
            }
            for(String key : objFileWrapListMap.keySet())
            {
                FileObjWrap fow = new FileObjWrap();
                fow.objName = key;
                fow.fileList = objFileWrapListMap.get(key);
                System.debug('fow --> ' + fow);
                fileObjList.add(fow);
            }
        }
        return fileObjList;
    }
}