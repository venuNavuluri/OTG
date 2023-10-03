public class QuoteInstallationController {

    public class QuoteRecordWrapper
    {
        @AuraEnabled
        public SBQQ__QuoteLineGroup__c qlg;
        @AuraEnabled
        public Package__c pack;
    }
    
    @AuraEnabled
    public static List<Installation__c> createRecords(String quoteId, String quoteGrpId, Integer count, String delvContact, String invAcc, String client)
    {
        try
        {
            //SBQQ__Quote__c quote = [SELECT Id, Name, SBQQ__Account__c FROM SBQQ__Quote__c WHERE Id = :quoteId];
            SBQQ__QuoteLineGroup__c qlg = [SELECT Id, Name, Package__c, SBQQ__Quote__r.SBQQ__Account__c, SBQQ__Quote__r.SBQQ__Type__c, SBQQ__Quote__r.SBQQ__MasterContract__c, SBQQ__Quote__c, SBQQ__Quote__r.Name, SBQQ__Quote__r.SBQQ__Account__r.Name FROM SBQQ__QuoteLineGroup__c WHERE Id = :quoteGrpId];
            String clientId;
            List<Installation__c> instList = new List<Installation__c>();
            System.debug('count --> ' + count);
            for(Integer i = 0; i < count; i++)
            {
                /* Installation_Type__c = type, Vessel_Name__c = vessel, Organisation_Name__c = org*/
                instList.add(new Installation__c(Contract_Customer__c = qlg.SBQQ__Quote__r.SBQQ__Account__c, Quote__c = qlg.SBQQ__Quote__c, Quote_Line_Group__c = quoteGrpId,
                Installation_Order_Status__c = 'Draft', Client__c = client, Delivery_Contact__c = delvContact, Invoice_Account__c = invAcc, Package__c = qlg.Package__c,
                Contract__c = qlg.SBQQ__Quote__r.SBQQ__MasterContract__c != NULL ? qlg.SBQQ__Quote__r.SBQQ__MasterContract__c : NULL));
            }
            insert instList;
            createInstallationLines(instList, new List<Id>{quoteGrpId});
            System.debug('instList --> ' + instList);
            List<Installation__c> installList = [SELECT Id, Name, Delivery_Contact__c, Delivery_Contact__r.Name, Client__c, Client__r.Name, Invoice_Account__c, Invoice_Account__r.Name, Contract_Customer__c, Contract_Customer__r.Name, Installation_Type__c, Vessel_Name__c, Vessel_Name__r.Name, Organisation_Name__c, Organisation_Name__r.Name FROM Installation__c WHERE Id IN :instList];
            return installList;
        }
        catch (Exception e) {
            System.debug('msg --> ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static string fetchQuoteLineGroups(String quoteId){
        try {
            List<SBQQ__QuoteLineGroup__c> quoteGroups = [Select Id,Name,Installation_Quantity__c,Package__c,
                                                        SBQQ__Quote__r.SBQQ__Account__c,
                                                        (Select Id,Name,Installation_Type__c,Vessel_Name__c,Vessel_Name__r.Name,Organisation_Name__c,Organisation_Name__r.Name,
                                                        Invoice_Account__c,Invoice_Account__r.Name,Client__c,Client__r.Name,Delivery_Contact__c,Delivery_Contact__r.Name
                                                        FROM Installations__r WHERE Installation_Order_Status__c != 'Terminated'),
                                                        (Select Id,Name,SBQQ__ProductName__c,SBQQ__Product__r.ProductCode
                                                        From SBQQ__LineItems__r)
                                                        From SBQQ__QuoteLineGroup__c
                                                        Where SBQQ__Quote__c =:quoteId Order By Name Asc];
            List<Id> packIdList = new List<Id>();
            for(SBQQ__QuoteLineGroup__c qlg : quoteGroups)
            {
                packIdList.add(qlg.Package__c);
            }
            Map<Id, Package__c> packMap = new Map<Id, Package__c>([SELECT Id, Name, 
                                                                    (SELECT Id,Name,Installation_Type__c,Vessel_Name__c,Vessel_Name__r.Name,Organisation_Name__c,Organisation_Name__r.Name,
                                                                    Invoice_Account__c,Invoice_Account__r.Name,Client__c,Client__r.Name,Delivery_Contact__c,Delivery_Contact__r.Name FROM Installations__r WHERE Installation_Order_Status__c != 'Terminated')
                                                                    FROM Package__c WHERE Id IN :packIdList]);
            List<QuoteRecordWrapper> qrwList = new List<QuoteRecordWrapper>();
            for(SBQQ__QuoteLineGroup__c qlg : quoteGroups)
            {
                QuoteRecordWrapper qrw = new QuoteRecordWrapper();
                qrw.qlg = qlg;
                qrw.pack = packMap.get(qlg.Package__c);
                qrwList.add(qrw);
            }
            return JSON.serialize(qrwList);
            
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
            List<Id> qlgIdList = new List<Id>();
            for(Installation__c inst : (List<Installation__c>)sobjList)
            {
                qlgIdList.add(inst.Quote_Line_Group__c);
            }
            Map<Id, SBQQ__QuoteLineGroup__c> qlgMap = new Map<Id, SBQQ__QuoteLineGroup__c>([SELECT Id, Name, Package__c, SBQQ__Quote__r.SBQQ__MasterContract__c, SBQQ__Quote__r.SBQQ__Type__c FROM SBQQ__QuoteLineGroup__c WHERE Id IN :qlgIdList]);
            for(Installation__c inst : (List<Installation__c>)sobjList)
            {
                inst.Package__c = qlgMap.get(inst.Quote_Line_Group__c).Package__c;
                inst.Contract__c = qlgMap.get(inst.Quote_Line_Group__c).SBQQ__Quote__r.SBQQ__MasterContract__c != NULL ? qlgMap.get(inst.Quote_Line_Group__c).SBQQ__Quote__r.SBQQ__MasterContract__c : NULL;
            }
            insert sobjList;
            createInstallationLines((List<Installation__c>)sObjList, qlgIdList);
            return [Select Id,Name,Installation_Type__c,Vessel_Name__c,Vessel_Name__r.Name,Organisation_Name__c,Organisation_Name__r.Name,
            Invoice_Account__c,Invoice_Account__r.Name,Client__c,Client__r.Name,Delivery_Contact__c,Delivery_Contact__r.Name From Installation__c Where Id IN:sobjList];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static void createInstallationLines(List<Installation__c> instList, List<Id> qlgIdList)
    {
        List<SBQQ__QuoteLine__c> qlList = new List<SBQQ__QuoteLine__c>([SELECT Id, Name, SBQQ__Group__c, SBQQ__Product__c, CurrencyIsoCode, SBQQ__Product__r.Name, SBQQ__StartDate__c, SBQQ__EndDate__c, SBQQ__NetTotal__c FROM SBQQ__QuoteLine__c WHERE SBQQ__Group__c IN :qlgIdList]);
        Map<Id, List<SBQQ__QuoteLine__c>> qlgIdQlListMap = new Map<Id, List<SBQQ__QuoteLine__c>>();
        for(SBQQ__QuoteLine__c ql : qlList)
        {
            if(qlgIdQlListMap.get(ql.SBQQ__Group__c) == NULL)
            {
                qlgIdQlListMap.put(ql.SBQQ__Group__c, new List<SBQQ__QuoteLine__c>());
            }
            qlgIdQlListMap.get(ql.SBQQ__Group__c).add(ql);
        }
        List<Installation_Line__c> instLines = new List<Installation_Line__c>();
        for(Installation__c inst : instList)
        {
            for(SBQQ__QuoteLine__c ql : qlgIdQlListMap.get(inst.Quote_Line_Group__c))
            {
                instLines.add(new Installation_Line__c(
                    Name = ql.SBQQ__Product__r.Name,
                    Installation__c = inst.Id,
                    Quote_Line__c = ql.Id,
                    Product__c = ql.SBQQ__Product__c,
                    Start_Date__c = ql.SBQQ__StartDate__c,
                    End_Date__c = ql.SBQQ__EndDate__c,
                    Net_Total__c = ql.SBQQ__NetTotal__c,
                    CurrencyIsoCode = ql.CurrencyIsoCode
                ));
            }
        }
        if(!instLines.isEmpty())
        {
            insert instLines;
        }
    }
}