public class CreateInstallationsController
{
    @AuraEnabled
    public static List<Package__c> getPackages(String contrId)
    {
        try
        {
            List<Package__c> packList = [SELECT Id, Name, Contract__c, Installation_Quantity__c FROM Package__c WHERE Contract__c = :contrId];
            return packList;
        }
        catch (Exception ex)
        {
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
            throw new AuraHandledException(ex.getMessage());
        }
    }
    
    @AuraEnabled
    public static String createNewInstRecord(Boolean isTerminate, String packId, String contrId, Installation__c inst)
    {
        try
        {
            if(!isTerminate)
            {
                Contract contr = [SELECT Id, Name, AccountId, (SELECT Id, Name FROM Installations__r WHERE Vessel_Name__c = :inst.Vessel_Name__c) FROM Contract WHERE Id = :contrId];
                if(inst.Vessel_Name__c != NULL && contr.Installations__r != NULL && contr.Installations__r.size() > 0)
                {
                    return 'Duplicate_Error';
                }
                inst.Contract__c = contrId;
                inst.Contract_Customer__c = contr.AccountId;
                inst.Package__c = packId;
                inst.Installation_Order_Status__c = 'Draft';
                inst.Installation_Start_Date__c = Date.today().addDays(30);
                insert inst;
            }
            SYstem.debug('before '+isTerminate);
            Date startDate = isTerminate ? inst.Termination_End_Date__c : Date.today().addDays(30);
            CreateInstallationsController.modifyContract(inst.Id, startDate, contrId, packId, isTerminate);
            SYstem.debug('after '+isTerminate);
            
            if(!isTerminate)
            {
                
                return 'SUCCESS: ' + inst.Id;
            }
            return 'SUCCESS';
        }
        catch (Exception ex)
        {
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
            throw new AuraHandledException(ex.getMessage());
        }
    }
    
    @future(callout=true)
    public static void modifyContract(Id instId, Date startDate, Id contrId, Id packId, Boolean isTerminate)
    {
        try
        {
            SBQQ__Quote__c qt;
            String qtId = '';
            try
            {
                String quoteJSON = SBQQ.ServiceRouter.load('SBQQ.ContractManipulationAPI.ContractAmender', contrId, NULL);
                System.debug('quoteJSON --> ' + quoteJSON);
                JSONParser jp = JSON.createParser(quoteJSON);
                jp.nextToken();
                while(jp.nextToken() != NULL)
                {
                    System.debug('ct --> ' + jp.getCurrentToken() + '-' + jp.getCurrentName());
                    if(jp.getCurrentName() == 'record')
                    {
                        while(jp.nextToken() != NULL)
                        {
                            if(jp.getText() == 'Id')
                            {
                                System.debug('id --> ' + jp.nextToken() + '-' + jp.getText());
                                qtId = jp.getText();
                                break;
                            }
                        }
                        break;
                    }
                    else{
                        jp.skipChildren();
                    }
                }
                System.debug('id --> ' + qtId);
                qt = [SELECT Id, Name, SBQQ__Status__c, SBQQ__Ordered__c, SBQQ__StartDate__c FROM SBQQ__Quote__c WHERE Id = :qtId ORDER BY CreatedDate DESC LIMIT 1];
            }
            catch(Exception ex)
            {
                Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
                Logger.saveLog();
                System.debug('ex --> ' + ex);
                System.debug('ex msg --> ' + ex.getMessage());
                System.debug('ex line --> ' + ex.getLineNumber());
                System.debug('ex st --> ' + ex.getStackTraceString());
                qt = [SELECT Id, Name, SBQQ__Status__c, SBQQ__Ordered__c, SBQQ__StartDate__c FROM SBQQ__Quote__c WHERE SBQQ__MasterContract__c = :contrId ORDER BY CreatedDate DESC LIMIT 1];
                System.debug('qt --> ' + qt);
            }
            Package__c pack = [SELECT Id, Name, Installation_Quantity__c FROM Package__c WHERE Id = :packId AND Contract__c = :contrId AND Quote__c = :qt.Id];
            System.debug('pack --> ' + pack);
            System.debug('pack ins quan --> ' + pack.Installation_Quantity__c);
            Decimal newInstallationQuantity = (pack.Installation_Quantity__c != null ? pack.Installation_Quantity__c : 0) + (isTerminate ? -1 : 1);
            pack.Installation_Quantity__c = newInstallationQuantity;
            update pack;
            SBQQ__QuoteLineGroup__c qlg= [SELECT Id, Name, Installation_Quantity__c FROM SBQQ__QuoteLineGroup__c WHERE Package__c = :packId AND SBQQ__Quote__c = :qt.Id];
            Decimal qlgnewInstallationQuantity = (qlg.Installation_Quantity__c != null ? qlg.Installation_Quantity__c : 0) + (isTerminate ? -1 : 1);
            qlg.Installation_Quantity__c = qlgnewInstallationQuantity;
            update qlg;
            
            //qt.SBQQ__Status__c = 'Approved';
            System.debug('isTerminate --> ' + isTerminate);
            if(isTerminate)
            {
                qt.Auto_Termination__c = TRUE;
                qt.Installation__c = instId;
                List<Installation__c> inst = [SELECT Id, Name, Termination_End_Date__c FROM Installation__c WHERE Id = :instId];
                qt.SBQQ__StartDate__c = inst[0].Termination_End_Date__c;
            }
            else
            {
                qt.Auto_Installation__c = TRUE;
                qt.Installation__c = instId;
                qt.SBQQ__StartDate__c = Date.today();
            }
            System.debug('qt --> ' + qt);
            update qt;
            
            if(!isTerminate)
            {
                Installation__c inst = new Installation__c();
                inst.Id = instId;
                inst.Quote_Line_Group__c = qlg.Id;
                inst.Installation_Start_Date__c = qt.SBQQ__StartDate__c;
                inst.Auto_Installation__c = TRUE;
                update inst;
                
                //goToInstallationLineCreation(new List<Id>{inst.Id});
                
            }
            CreateOrderScheduler cos = new CreateOrderScheduler();
            cos.qtId = qt.Id;
            Time t = DateTime.now().addMinutes(2).time();
            Date dt = DateTime.now().addMinutes(2).date();
            String cronExp = '00 ' + t.minute() + ' ' + t.hour() + ' ' + dt.day() + ' ' + dt.month() + ' ? ' + dt.year();
            String jobId = System.schedule('Create Order ' + qt.Id, cronExp, cos);
        }
        catch(Exception ex)
        {
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
            System.debug('ex --> ' + ex);
            System.debug('ex line --> ' + ex.getLineNumber());
        }
    }
    
    public static void goToInstallationLineCreation(List<Id> instIdList)
    {
        try
        {
            List<Installation__c> instList = [SELECT Id, Name, Contract__c, Order__c FROM Installation__c WHERE Id IN :instIdList];
            List<Id> contrIdList = new List<Id>();
            List<Id> ordIdList = new List<Id>();
            for(Installation__c inst : instList)
            {
                contrIdList.add(inst.Contract__c);
                if(inst.Order__c != NULL)
                {
                    ordIdList.add(inst.Order__c);
                }
            }
            List<SBQQ__Subscription__c> subList = new List<SBQQ__Subscription__c>();//[SELECT Id, Name, CurrencyIsoCode, SBQQ__NetPrice__c, SBQQ__StartDate__c, SBQQ__EndDate__c, SBQQ__Product__c, SBQQ__Product__r.Name, Package__c, SBQQ__Contract__c, SBQQ__OrderProduct__c, SBQQ__OrderProduct__r.SBQQ__ContractAction__c FROM SBQQ__Subscription__c WHERE SBQQ__Contract__c IN :contrIdList AND SBQQ__OrderProduct__r.OrderId IN :ordIdList];
            
            if(ordIdList.isEmpty())
            {
                subList = [SELECT Id, Name, CurrencyIsoCode, SBQQ__NetPrice__c, SBQQ__StartDate__c, SBQQ__EndDate__c, SBQQ__Product__c, SBQQ__Product__r.Name, Package__c, SBQQ__Contract__c, SBQQ__OrderProduct__c, SBQQ__OrderProduct__r.SBQQ__ContractAction__c FROM SBQQ__Subscription__c WHERE SBQQ__Contract__c IN :contrIdList];
            }
            else
            {
                subList = [SELECT Id, Name, CurrencyIsoCode, SBQQ__NetPrice__c, SBQQ__StartDate__c, SBQQ__EndDate__c, SBQQ__Product__c, SBQQ__Product__r.Name, Package__c, SBQQ__Contract__c, SBQQ__OrderProduct__c, SBQQ__OrderProduct__r.SBQQ__ContractAction__c FROM SBQQ__Subscription__c WHERE SBQQ__Contract__c IN :contrIdList AND SBQQ__OrderProduct__r.OrderId IN :ordIdList];
            }
            System.debug('subList --> ' + subList);
            createInstallationLines(subList);
        }
        catch(Exception ex)
        {
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
        }
    }
    
    public static void createInstallationLines(List<SBQQ__Subscription__c> subList)
    {
        try
        {
            Map<Id, List<SBQQ__Subscription__c>> packIdSubListMap = new Map<Id, List<SBQQ__Subscription__c>>();
            for(SBQQ__Subscription__c sub : subList)
            {
                if(packIdSubListMap.get(sub.Package__c) == NULL)
                {
                    packIdSubListMap.put(sub.Package__c, new List<SBQQ__Subscription__c>());
                }
                packIdSubListMap.get(sub.Package__c).add(sub);
            }
            Map<Id, Package__c> packMap = new Map<Id, Package__c>([SELECT Id, Name, Quote__r.Auto_Installation__c, (SELECT Id, Name, Auto_Installation__c, Installation_Start_Date__c, Installation_End_Date__c FROM Installations__r) FROM Package__c WHERE Id IN :packIdSubListMap.keySet()]);
            List<Installation_Line__c> instLines = new List<Installation_Line__c>();
            for(Id packId : packIdSubListMap.keySet())
            {
                List<SBQQ__Subscription__c> subscList = packIdSubListMap.get(packId);
                if(subscList != NULL && !subscList.isEmpty())
                {
                    for(SBQQ__Subscription__c sub : subscList)
                    {
                        if(packMap.get(packId) != NULL && packMap.get(packId).Installations__r != NULL && !packMap.get(packId).Installations__r.isEmpty())
                        {
                            for(Installation__c inst : packMap.get(packId).Installations__r)
                            {
                                if(!packMap.get(packId).Quote__r.Auto_Installation__c || inst.Auto_Installation__c)
                                {
                                    instLines.add(new Installation_Line__c(
                                        Name = sub.SBQQ__Product__r.Name,
                                        Installation__c = inst.Id,
                                        Subscription__c = sub.Id,
                                        Product__c = sub.SBQQ__Product__c,
                                        Start_Date__c = sub.SBQQ__StartDate__c,
                                        End_Date__c = inst.Installation_End_date__c > sub.SBQQ__EndDate__c ? inst.Installation_End_date__c : sub.SBQQ__EndDate__c,
                                        Net_Total__c = sub.SBQQ__NetPrice__c,
                                        CurrencyIsoCode = sub.CurrencyIsoCode
                                    ));
                                }
                            }
                        }
                    }
                }
            }
            System.debug('instLines --> ' + instLines);
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
    
    
    /*private class QuoteCalculatorContext
    {        
        private QuoteModel quote;
        private String callbackClass;
        
        private QuoteCalculatorContext(QuoteModel quote, String callbackClass)
        {
            this.quote = quote;            
            this.callbackClass = callbackClass;        
        }
    } */
    
    
    @AuraEnabled
    public static Boolean checkDuplicates(String contrId, String vesId, String orgId)
    {
        try
        {
            List<Installation__c> instList;
            if(vesId != NULL && vesId != '')
            {
                instList = [SELECT Id, Name, Vessel_Name__c, Organisation_Name__c FROM Installation__c WHERE Vessel_Name__c = :vesId AND Contract__c = :contrId];
            }
            else
            {
                instList = [SELECT Id, Name, Vessel_Name__c, Organisation_Name__c FROM Installation__c WHERE Organisation_Name__c = :orgId AND Contract__c = :contrId];
            }
            if(!instList.isEmpty())
            {
                return TRUE;
            }
            else
            {
                return FALSE;
            }
        }
        catch (Exception ex)
        {
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
            throw new AuraHandledException(ex.getMessage());
        }
    }
    
    @AuraEnabled
    public static string terminateSingleRecord(String instId, Date endDate, String reason)
    {
        return terminateRecords(new List<String>{instId}, endDate, reason);
    }
    
    @AuraEnabled
    public static string terminateRecords(List<String> instIdList, Date endDate, String reason)
    {
        try
        {
            List<Installation__c> instList = new List<Installation__c>();
            for(String instId : instIdList)
            {
                Installation__c inst = new Installation__c(
                    Id = instId,
                    Installation_Order_Status__c = endDate > Date.today() ? 'Future Terminated' : 'Terminated',
                    Termination_End_Date__c = endDate,
                    Termination_Reason__c = reason,
                    Auto_Termination__c = TRUE
                );
                instList.add(inst);
            }
            System.debug('instList --> ' + instList);
            if(!instList.isEmpty())
            {
                update instList;
            }
            instList = [SELECT Id, Name, Package__c, Contract__c, Termination_End_Date__c FROM Installation__c WHERE Id IN :instIdList];
            createNewInstRecord(TRUE, instList[0].Package__c, instList[0].Contract__c, instList[0]);
            return 'SUCCESS';
        }
        catch (Exception ex)
        {
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
            throw new AuraHandledException(ex.getMessage());
        }
    }
    
    @AuraEnabled
    public static List<InstallationData> getInstallations(String contrId)
    {
        try
        {
            List<InstallationData> instDataList = new List<InstallationData>();
            for(Installation__c inst : [SELECT Id, Name, Invoice_Account__c, Contract_Customer__c, Contract_Customer__r.Name, Installation_Order_Status__c, Installation_Start_date__c, Installation_End_date__c, Vessel_IMO__c, Vessel_Status__c, Invoice_Account__r.Name, Vessel_Name__c, Vessel_Name__r.Name, Contract__c, Contract__r.Name FROM Installation__c WHERE Contract__c = :contrId AND Installation_Order_Status__c != 'Terminated'])
            {
                InstallationData instData = new InstallationData();
                instData.InstId = inst.Id;
                instData.InstUrl = '/' + inst.Id;
                instData.InstName = inst.Name;
                instData.VesselName = inst.Vessel_Name__r.Name;
                instData.VesselIMO = inst.Vessel_IMO__c;
                instData.VesselStatus = inst.Vessel_Status__c;
                instData.InstStatus = inst.Installation_Order_Status__c;
                instData.startDate = inst.Installation_Start_Date__c;
                instData.endDate = inst.Installation_End_date__c;
                instData.CustContractName = inst.Contract_Customer__r.Name;
                instData.CustContractId = inst.Contract_Customer__c;
                instData.CustContractUrl = '/' + inst.Contract_Customer__c;
                instDataList.add(instData);
            }
            return instDataList;
        }
        catch (Exception ex)
        {
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
            throw new AuraHandledException(ex.getMessage());
        }
    }
    
    @AuraEnabled
    public static List<Installation__c> getInstallationRecs(String contrId)
    {
        try
        {
            return [SELECT Id, Name, Invoice_Account__c, Invoice_Account__r.Name, Vessel_Name__c, Vessel_Name__r.Name, Contract__c, Contract__r.Name FROM Installation__c WHERE Contract__c = :contrId AND Installation_Order_Status__c != 'Terminated'];
        }
        catch (Exception ex)
        {
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
            throw new AuraHandledException(ex.getMessage());
        }
    }
    
    public class InstallationData
    {
        @AuraEnabled
        public String InstId;
        @AuraEnabled
        public String InstUrl;
        @AuraEnabled
        public String InstName;
        @AuraEnabled
        public String VesselName;
        @AuraEnabled
        public String VesselIMO;
        @AuraEnabled
        public String VesselStatus;
        @AuraEnabled
        public String InstStatus;
        @AuraEnabled
        public String CustContractId;
        @AuraEnabled
        public String CustContractUrl;
        @AuraEnabled
        public String CustContractName;
        @AuraEnabled
        public Date startDate;
        @AuraEnabled
        public Date endDate;
    }
}