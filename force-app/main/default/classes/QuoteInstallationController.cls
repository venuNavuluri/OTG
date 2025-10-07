public class QuoteInstallationController {

    public class QuoteRecordWrapper
    {
        @AuraEnabled
        public SBQQ__QuoteLineGroup__c qlg;
        @AuraEnabled
        public Package__c pack;
        @AuraEnabled
        public Decimal userPrice;
        @AuraEnabled
        public Decimal installationPrice;
    }

    @AuraEnabled
    public static string createInstallations(String conVerId, String qtId, String qlgId, Decimal instPrice)
    {
        try
        {
            ContentVersion conVer = [SELECT Id, VersionData FROM ContentVersion WHERE Id = :conVerId];
            Map<Id, SBQQ__QuoteLineGroup__c> qlgMap = new Map<Id, SBQQ__QuoteLineGroup__c>([SELECT Id, Name, Package__c, SBQQ__Quote__c, SBQQ__Quote__r.SBQQ__MasterContract__c, SBQQ__Quote__r.SBQQ__Type__c, SBQQ__Quote__r.SBQQ__Account__c, SBQQ__Quote__r.SBQQ__SalesRep__r.Email, SBQQ__Quote__r.CurrencyISOCode FROM SBQQ__QuoteLineGroup__c WHERE Id = :qlgId]);
            String st = conVer.VersionData.toString();
            System.debug('conVer --> ' + conVer.VersionData.toString());
            System.debug('st --> ' + st);
            Map<String, String> vesIMORecMap = new Map<String, String>();
            List<String> invAccNameList = new List<String>();
            Integer i = 0;
            for(String rec : st.split('\n'))
            {
                if(i != 0)
                {
                    String str;
                    if(st.split('\n').size() != (i + 1))
                    {
                        str = rec.subString(0, rec.length() - 1);
                    }
                    else
                    {
                        str = rec.subString(0);
                    }
                    System.debug('n --> ' + str.charAt(str.length()-2));
                    System.debug('str --> ' + str.contains('\r') + ' ' + str.charAt(str.length()-1) + ' ' + str.codePointAt(str.length()-1) + ' ' + String.valueOf(str.codePointAt(str.length()-1)).unescapeUnicode());
                    if(str.contains('\r'))
                    {
                        str = str.subString(0, str.length() - 1);
                    }
                    List<String> recList = str.split(',');
                    vesIMORecMap.put(recList[0], str);
                    System.debug('recList[1] --> ' + recList[1].contains('\n'));
                    /*if(recList[1].contains('\n'))
                    {
                        recList[1] = recList[1].subString(0, recList[1].length() - 1);
                    }*/
                    invAccNameList.add(recList[1]);
                }
                System.debug('vesIMORecMap --> ' + vesIMORecMap);
                i++;
            }
            System.debug('invnames --> ' + invAccNameList);
            Map<Id, Vessel__c> vesMap = new Map<Id, Vessel__c>([SELECT Id, Name, Vessel_IMO__c FROM Vessel__c WHERE Vessel_IMO__c IN :vesIMORecMap.keySet()]);
            List<Account> invAccList = [SELECT Id, Name, Account_ID__c FROM Account WHERE Account_ID__c IN :invAccNameList];
            System.debug('invs --> ' + invAccList);
            Map<String, Account> invAccMap = new Map<String, Account>();
            for(Account acc : invAccList)
            {
                invAccMap.put(acc.Account_ID__c, acc);
            }
            System.debug('invAccMap --> ' + invAccMap);
            Set<String> vesIMOSet = new Set<String>();
            for(Vessel__c ves : vesMap.values())
            {
                vesIMOSet.add(ves.Vessel_IMO__c);
            }
            List<Installation__c> instList = new List<Installation__c>();
            String noIMO = 'VesselIMO,Error\n';
            Map<String, Installation__c> vesInstMap = new Map<String, Installation__c>();
            for(Vessel__c ves : vesMap.values())
            {
                System.debug('id --> ' + ves.Vessel_IMO__c);
                System.debug('rec --> ' + vesIMORecMap.get(ves.Vessel_IMO__c));
                System.debug('rec --> ' + vesIMORecMap.get(ves.Vessel_IMO__c).split(',')[1]);
                System.debug('val --> ' + invAccMap.get(vesIMORecMap.get(ves.Vessel_IMO__c).split(',')[1]));
                if(invAccMap.get(vesIMORecMap.get(ves.Vessel_IMO__c).split(',')[1]) != NULL)
                {
                    Installation__c inst = new Installation__c(
                        Installation_Type__c = 'Vessel',
                        Invoice_Account__c = invAccMap.get(vesIMORecMap.get(ves.Vessel_IMO__c).split(',')[1]).Id,
                        Vessel_Name__c = ves.Id,
                        Quote__c = qlgMap.get(qlgId).SBQQ__Quote__c,
                        Quote_Line_Group__c = qlgId,
                        Package__c = qlgMap.get(qlgId).Package__c,
                        Contract__c = qlgMap.get(qlgId).SBQQ__Quote__r.SBQQ__MasterContract__c,
                        Installation_Order_Status__c = 'Draft',
                        Contract_Customer__c = qlgMap.get(qlgId).SBQQ__Quote__r.SBQQ__Account__c,
                        CurrencyISOCode = qlgMap.get(qlgId).SBQQ__Quote__r.CurrencyISOCode,
                        Installation_Price__c = instPrice
                    );
                    instList.add(inst);
                    vesInstMap.put(ves.Vessel_IMO__c, inst);
                }
                else
                {
                    noIMO += ves.Vessel_IMO__c + ',Invoice Account not present\n';
                }
            }
            Database.saveResult[] sr;
            if(!instList.isEmpty())
            {
                sr = Database.insert(instList, false);
            }
            i = 0;
            Integer newInstCount = 0;
            List<Installation__c> instListInserted = new List<Installation__c>();
            for(Installation__c inst : instList)
            {
                if(!sr[i].isSuccess())
                {
                    noIMO += vesMap.get(instList[i].Vessel_Name__c).Vessel_IMO__c + ',';
                    for(Database.Error err : sr[i].getErrors())
                    {
                        noIMO += err.getMessage() + '. ';
                    }
                    noIMO += '\n';
                }
                else
                {
                    newInstCount++;
                    instListInserted.add(instList[i]);
                }
                i++;
            }
            createInstallationLines(instListInserted, new List<Id>{qlgId});
            if(vesIMORecMap.keySet().size() != instList.size())
            {
                for(String imo : vesIMORecMap.keySet())
                {
                    if(!vesIMOSet.contains(imo))
                    {
                        noIMO += imo + ',IMO Not Present\n';
                    }
                }
                BLOB b;
                if(Test.isRunningTest())
                { 
                    b = BLOB.valueOf('Unit.Test');
                }
                else
                {
                    b = BLOB.valueOf(noIMO);
                }
                Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
                Messaging.EmailFileAttachment attach = new Messaging.EmailFileAttachment();
                attach.setFileName('Failed Records.csv');
                attach.setBody(b);
                message.setFileAttachments(new Messaging.EmailFileAttachment[]{attach});
                String[] toAddresses = new String[] {qlgMap.values()[0].SBQQ__Quote__r.SBQQ__SalesRep__r.Email}; 
                message.setToAddresses(toAddresses); 
                message.setSubject('IMOs\' not present to create the Installations'); 
                message.setHtmlBody('PFA, the list of IMOs\' that are not present in the Vessel records');
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { message });
            }
            return newInstCount + Label.Upload_Installations_Success_Message;
        }
        catch (Exception ex)
        {
            System.debug(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
            throw new AuraHandledException(ex.getMessage());
        }
    }
    
    @AuraEnabled
    public static List<Installation__c> createRecords(String quoteId, String quoteGrpId, Integer count, String delvContact, String invAcc, String client)
    {
        try
        {
            //SBQQ__Quote__c quote = [SELECT Id, Name, SBQQ__Account__c FROM SBQQ__Quote__c WHERE Id = :quoteId];
            SBQQ__QuoteLineGroup__c qlg = [SELECT Id, Name, Package__c, SBQQ__Quote__r.CurrencyISOCode, SBQQ__Quote__r.SBQQ__Account__c, SBQQ__Quote__r.SBQQ__Type__c, SBQQ__Quote__r.SBQQ__MasterContract__c, SBQQ__Quote__c, SBQQ__Quote__r.Name, SBQQ__Quote__r.SBQQ__Account__r.Name, CurrencyISOCode FROM SBQQ__QuoteLineGroup__c WHERE Id = :quoteGrpId];
            String clientId;
            List<Installation__c> instList = new List<Installation__c>();
            System.debug('count --> ' + count);
            for(Integer i = 0; i < count; i++)
            {
                /* Installation_Type__c = type, Vessel_Name__c = vessel, Organisation_Name__c = org*/
                instList.add(new Installation__c(Contract_Customer__c = qlg.SBQQ__Quote__r.SBQQ__Account__c, Quote__c = qlg.SBQQ__Quote__c, Quote_Line_Group__c = quoteGrpId,CurrencyISOCode = qlg.CurrencyISOCode,
                Installation_Order_Status__c = 'Draft', Client__c = client, Delivery_Contact__c = delvContact, Invoice_Account__c = invAcc, Package__c = qlg.Package__c,
                Contract__c = qlg.SBQQ__Quote__r.SBQQ__MasterContract__c != NULL ? qlg.SBQQ__Quote__r.SBQQ__MasterContract__c : NULL));
            }
            insert instList;
            createInstallationLines(instList, new List<Id>{quoteGrpId});
            System.debug('instList --> ' + instList);
            List<Installation__c> installList = [SELECT Id, Name, Delivery_Contact__c, Delivery_Contact__r.Name, Client__c, Client__r.Name, Invoice_Account__c, Invoice_Account__r.Name, Contract_Customer__c, Contract_Customer__r.Name, Installation_Type__c, Vessel_Name__c, Vessel_Name__r.Name, Organisation_Name__c, Organisation_Name__r.Name, Change_Package_Status__c FROM Installation__c WHERE Id IN :instList];
            return installList;
        }
        catch (Exception ex) {
            System.debug('msg --> ' + ex.getMessage());
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
            throw new AuraHandledException(ex.getMessage());
        }
    }
    
    @AuraEnabled
    public static string fetchQuoteLineGroups(String quoteId){
        try {
            List<SBQQ__Quote__c> qtList = [SELECT Id, Name, SBQQ__Type__c, SBQQ__MasterContract__c, SBQQ__MasterContract__r.SBQQ__Quote__c FROM SBQQ__Quote__c WHERE Id = :quoteId];
            List<Id> qtIdList = new List<Id>();
            if(qtList[0].SBQQ__Type__c == 'Amendment')
            {
                List<SBQQ__Quote__c> allQtList = [SELECT Id, Name, SBQQ__Type__c, SBQQ__MasterContract__c FROM SBQQ__Quote__c WHERE SBQQ__MasterContract__c = :qtList[0].SBQQ__MasterContract__c];
                qtIdList.add(qtList[0].SBQQ__MasterContract__r.SBQQ__Quote__c);
                for(SBQQ__Quote__c qt : allQtList)
                {
                    qtIdList.add(qt.Id);
                }
            }
            qtIdList.add(quoteId);
            List<SBQQ__QuoteLineGroup__c> quoteGroups = [Select Id,Name,Installation_Quantity__c,Package__c, SBQQ__Quote__r.SBQQ__Type__c,SBQQ__Quote__c,Installation_Price__c,
                                                        SBQQ__Quote__r.SBQQ__Account__c, User_Quantity__c, CurrencyIsoCode,Package__r.Name, 
                                                        (Select Id,Name,Installation_Type__c,Vessel_Name__c,Vessel_Name__r.Name,Organisation_Name__c,Organisation_Name__r.Name,Package__c,
                                                        Invoice_Account__c,Invoice_Account__r.Name,Client__c,Client__r.Name,Delivery_Contact__c,Delivery_Contact__r.Name, Quote__c, Quote__r.Name,Change_Package_Status__c 
                                                        FROM Installations__r WHERE Installation_Order_Status__c != 'Terminated'),
                                                        (Select Id,Name,SBQQ__ProductName__c,SBQQ__Product__r.ProductCode, SBQQ__StartDate__c, SBQQ__EndDate__c, SBQQ__NetPrice__c, SBQQ__NetTotal__c, CurrencyIsoCode, SBQQ__Quote__r.SBQQ__Type__c
                                                        From SBQQ__LineItems__r)
                                                        From SBQQ__QuoteLineGroup__c
                                                        Where SBQQ__Quote__c =:qtIdList Order BY CreatedDate ASC];
            List<Id> packIdList = new List<Id>();
            for(SBQQ__QuoteLineGroup__c qlg : quoteGroups)
            {
                packIdList.add(qlg.Package__c);
            }
            Map<Id, Package__c> packMap = new Map<Id, Package__c>([SELECT Id, Name, 
                                                                    (SELECT Id,Name,Installation_Type__c,Vessel_Name__c,Vessel_Name__r.Name,Organisation_Name__c,Organisation_Name__r.Name, Quote__c, Quote__r.Name,Package__c,Package__r.Name, 
                                                                    Invoice_Account__c,Invoice_Account__r.Name,Client__c,Client__r.Name,Delivery_Contact__c,Delivery_Contact__r.Name, Change_Package_Status__c FROM Installations__r WHERE Installation_Order_Status__c != 'Terminated')
                                                                    FROM Package__c WHERE Id IN :packIdList]);
            List<QuoteRecordWrapper> qrwList = new List<QuoteRecordWrapper>();
            Map<Id, QuoteRecordWrapper> qrwPackMap = new Map<Id, QuoteRecordWrapper>();
            for(SBQQ__QuoteLineGroup__c qlg : quoteGroups)
            {
                
                QuoteRecordWrapper qrw = new QuoteRecordWrapper();
                if(qrwPackMap.get(qlg.Package__c) != NULL)
                {
                    qrw = qrwPackMap.get(qlg.Package__c);
                }
                qrw.qlg = qlg;
                qrw.pack = packMap.get(qlg.Package__c);
                qrw.installationPrice = (qlg.Installation_Price__c == null)
                    ? 0
                    : qlg.Installation_Price__c.setScale(2);
                qrw.userPrice = (qrw.installationPrice == 0 || qlg.User_Quantity__c == null || qlg.User_Quantity__c == 0)
                    ? 0
                    : (qrw.installationPrice / qlg.User_Quantity__c).setScale(2);
                //qrwList.add(qrw);
                qrwPackMap.put(qlg.Package__c, qrw);
            }
            qrwList.addAll(qrwPackMap.values());
            System.debug('qrwList --> ' + JSON.serialize(qrwList));
            return JSON.serialize(qrwList);
            
        }
        catch (Exception ex)
        {
            System.debug(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
            throw new AuraHandledException(ex.getMessage());
        }
    }
    @AuraEnabled
    public static String fetchQuoteLineGroupProducts(String quoteGrpId)
    {
        try
        {
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
        }
        catch (Exception ex)
        {
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
            throw new AuraHandledException(ex.getMessage());
        }
    }
    @AuraEnabled
    public static List<sObject> saveInstallation(List<sObject> sobjList)
    {
        try
        {
            List<Id> qlgIdList = new List<Id>();
            for(Installation__c inst : (List<Installation__c>)sobjList)
            {
                qlgIdList.add(inst.Quote_Line_Group__c);
            }
            Map<Id, SBQQ__QuoteLineGroup__c> qlgMap = new Map<Id, SBQQ__QuoteLineGroup__c>([SELECT Id, Name, SBQQ__Quote__c, SBQQ__Quote__r.CurrencyISOCode, SBQQ__Quote__r.SBQQ__Account__c, Package__c, SBQQ__Quote__r.SBQQ__MasterContract__c, SBQQ__Quote__r.SBQQ__Type__c FROM SBQQ__QuoteLineGroup__c WHERE Id IN :qlgIdList]);
            for(Installation__c inst : (List<Installation__c>)sobjList)
            {
                inst.Installation_Order_Status__c = 'Draft';
                inst.CurrencyIsoCode = qlgMap.get(inst.Quote_Line_Group__c).SBQQ__Quote__r.CurrencyISOCode;
                inst.Contract_Customer__c = qlgMap.get(inst.Quote_Line_Group__c).SBQQ__Quote__r.SBQQ__Account__c;
                inst.Quote__c = qlgMap.get(inst.Quote_Line_Group__c).SBQQ__Quote__c;
                inst.Package__c = qlgMap.get(inst.Quote_Line_Group__c).Package__c;
                inst.Contract__c = qlgMap.get(inst.Quote_Line_Group__c).SBQQ__Quote__r.SBQQ__MasterContract__c != NULL ? qlgMap.get(inst.Quote_Line_Group__c).SBQQ__Quote__r.SBQQ__MasterContract__c : NULL;
            }
            insert sobjList;
            //createInstallationLines((List<Installation__c>)sObjList, qlgIdList);
            return [Select Id,Name,Installation_Type__c,Vessel_Name__c,Vessel_Name__r.Name,Organisation_Name__c,Organisation_Name__r.Name, Quote__r.Name,Package__c,
            Invoice_Account__c,Invoice_Account__r.Name,Client__c,Client__r.Name,Delivery_Contact__c,Delivery_Contact__r.Name, Change_Package_Status__c From Installation__c Where Id IN:sobjList];
        }
        catch (Exception ex)
        {
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
            throw new AuraHandledException(ex.getMessage());
        }
    }

    public static void createInstallationLines(List<Installation__c> instList, List<Id> qlgIdList)
    {
        try
        {
            List<SBQQ__QuoteLine__c> qlList = new List<SBQQ__QuoteLine__c>([SELECT Id, Name, SBQQ__Group__c, SBQQ__Product__c, CurrencyIsoCode, SBQQ__Product__r.Name, SBQQ__StartDate__c, SBQQ__EndDate__c, SBQQ__NetTotal__c, SBQQ__NetPrice__c FROM SBQQ__QuoteLine__c WHERE SBQQ__Group__c IN :qlgIdList]);
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
                        Net_Total__c = ql.SBQQ__NetPrice__c,
                        CurrencyIsoCode = ql.CurrencyIsoCode
                    ));
            }
        }
        if(!instLines.isEmpty())
        {
            insert instLines;
        }
        }
        catch(Exception ex)
        {
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
        }
    }
    // In UpdatePackageController.cls
    @AuraEnabled
    public static void saveInstallationToQLG(Id instId, Id targetQlgId, Id quoteId) {
        try {
            if (instId == null || targetQlgId == null || quoteId == null) {
                throw new AuraHandledException('Invalid request. Missing Installation, QLG, or Quote.');
            }

            // Target QLG (need its Package and Installation_Quantity__c)
            SBQQ__QuoteLineGroup__c targetQLG = [
                SELECT Id, Name, Package__c, Installation_Quantity__c,
                    SBQQ__Quote__c, SBQQ__Quote__r.SBQQ__Type__c
                FROM SBQQ__QuoteLineGroup__c
                WHERE Id = :targetQlgId
                LIMIT 1
            ];

            if (targetQLG.Package__c == null) {
                throw new AuraHandledException('Selected Quote Line Group does not have an associated Package.');
            }

            // Installation being moved (need current QLG & Package)
            Installation__c inst = [
                SELECT Id, Package__c, Quote_Line_Group__c, Change_Package_Status__c 
                FROM Installation__c
                WHERE Id = :instId
                FOR UPDATE
            ];

            // If we’re moving INTO a different QLG, enforce QLG capacity.
            // (If same QLG, allow — no net capacity change.)
            if (inst.Quote_Line_Group__c != targetQLG.Id) {
                Integer cap = (targetQLG.Installation_Quantity__c == null)
                    ? 0
                    : Integer.valueOf(targetQLG.Installation_Quantity__c);

                // Count current (non-terminated) installations in the target QLG
                Integer currentCount = [
                    SELECT COUNT()
                    FROM Installation__c
                    WHERE Package__c = :targetQLG.Package__c
                    AND Installation_Order_Status__c != 'Terminated'
                ];

                // Only enforce when cap > 0 (cap==0 treated as unlimited — preserves prior semantics)
                if (cap > 0 && currentCount >= cap) {
                    throw new AuraHandledException('Target quote line group is at capacity. Please choose a different group.');
                }
            }

            // Overwrite fields per requirement
            inst.Quote__c = quoteId;
            inst.Quote_Line_Group__c = targetQLG.Id;
            inst.Package__c = targetQLG.Package__c;
            inst.Change_Package_Status__c = 'In Progress';

            update inst;

        } catch (Exception ex) {
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
            throw (ex instanceof AuraHandledException)
                ? ex
                : new AuraHandledException('Failed to move installation: ' + ex.getMessage());
        }
    }
}