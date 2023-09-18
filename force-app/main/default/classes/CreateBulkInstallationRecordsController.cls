public with sharing class CreateBulkInstallationRecordsController {
    public CreateBulkInstallationRecordsController() {

    }
    /*, String type, String vessel, String org, Invoice_Account__c, Client__c*/
    @AuraEnabled
    public static List<InstallationWrapper> createRecords(String quoteId, String quoteGrpId, Integer count)
    {
        try
        {
            List<InstallationWrapper> instWrapList = new List<InstallationWrapper>();
            //SBQQ__Quote__c quote = [SELECT Id, Name, SBQQ__Account__c FROM SBQQ__Quote__c WHERE Id = :quoteId];
            SBQQ__QuoteLineGroup__c qlg = [SELECT Id, Name, SBQQ__Quote__r.SBQQ__Account__c, SBQQ__Quote__c, SBQQ__Quote__r.Name, SBQQ__Quote__r.SBQQ__Account__r.Name FROM SBQQ__QuoteLineGroup__c WHERE Id = :quoteGrpId];
            String clientId;
            List<Installation__c> instList = new List<Installation__c>();
            System.debug('count --> ' + count);
            for(Integer i = 0; i < count; i++)
            {
                /* Installation_Type__c = type, Vessel_Name__c = vessel, Organisation_Name__c = org*/
                instList.add(new Installation__c(Contract_Customer__c = qlg.SBQQ__Quote__r.SBQQ__Account__c, Quote__c = qlg.SBQQ__Quote__c, Quote_Line_Group__c = quoteGrpId,
                Installation_Order_Status__c = 'Draft'));
            }
            insert instList;
            System.debug('instList --> ' + instList);
            List<Installation__c> installList = [SELECT Id, Name, Delivery_Contact__c, Client__c, Invoice_Account__c, Contract_Customer__c, Contract_Customer__r.Name, Installation_Type__c, Vessel_Name__c, Vessel_Name__r.Name, Organisation_Name__c, Organisation_Name__r.Name FROM Installation__c WHERE Id IN :instList];
            //return installList;
            for(Installation__c inst : installList)
            {
                System.debug('name --> ' + inst.Name);
                instWrapList.add(new InstallationWrapper(inst));
            }
            return instWrapList;
        }
        catch (Exception e) {
            System.debug('msg --> ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<InstallationWrapper> getExistingInstallationRecords(String quoteGrpId)
    {
        try
        {
            SBQQ__QuoteLineGroup__c qlg = [SELECT Id, Name, SBQQ__Quote__c, SBQQ__Quote__r.SBQQ__Account__c, Installation_Quantity__c FROM SBQQ__QuoteLineGroup__c WHERE Id = :quoteGrpId];
            List<Installation__c> instList = [SELECT Id, Name, Delivery_Contact__c, Delivery_Contact__r.Name, Invoice_Account__c, Client__c, Invoice_Account__r.Name, Client__r.Name, Vessel_Name__c, Vessel_Name__r.Name, Contract_Customer__c, Contract_Customer__r.Name, Organisation_Name__c, Organisation_Name__r.Name, Installation_Type__c FROM Installation__c WHERE Quote_Line_Group__c = :quoteGrpId AND Contract_Customer__c = :qlg.SBQQ__Quote__r.SBQQ__Account__c];
            List<InstallationWrapper> instWrapList = new List<InstallationWrapper>();
            for(Installation__c inst : instList)
            {
                InstallationWrapper instWrapRec = new InstallationWrapper(inst);
                instWrapRec.InstallationType = inst.Installation_Type__c;
                instWrapRec.vesselName = inst.Vessel_Name__r.Name;
                instWrapRec.OrganisationName = inst.Organisation_Name__r.Name;
                instWrapRec.VesOrgName = inst.Installation_Type__c == 'Vessel' ? inst.Vessel_Name__r.Name : inst.Organisation_Name__r.Name;
                instWrapList.add(instWrapRec);
            }
            return instWrapList;
        } catch (Exception e) {
            System.debug('e --> ' + e);
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Integer validateCount(String quoteGrpId, Integer count)
    {
        SBQQ__QuoteLineGroup__c qlg = [SELECT Id, Name, SBQQ__Quote__c, SBQQ__Quote__r.SBQQ__Account__c, Installation_Quantity__c FROM SBQQ__QuoteLineGroup__c WHERE Id = :quoteGrpId];
        List<Installation__c> instList = [SELECT Id, Name, Contract_Customer__c FROM Installation__c WHERE Quote_Line_Group__c = :quoteGrpId AND Contract_Customer__c = :qlg.SBQQ__Quote__r.SBQQ__Account__c];
        if(qlg.Installation_Quantity__c != NULL)
        {
            Integer instCount = (instList != NULL && !instList.isEmpty()) ? instList.size() : 0;
            System.debug('check1 --> ' + qlg.Installation_Quantity__c);
            System.debug('check --> ' + instCount);
            System.debug('count --> ' + count);
            Integer remainingQty = Integer.valueOf(qlg.Installation_Quantity__c - instCount);
            System.debug('remainingQty --> ' + remainingQty);
            return remainingQty >= 0 ? remainingQty : 0;
        }
        return 0;
    }

    @AuraEnabled
    public static List<InstallationWrapper> updateInstallationRecords(String allRecsStr, String instWrapListStr, String instType, String vesselType, String orgType, String delvCont, String client, String invAcc)
    {
        try
        {
            System.debug('instWrapListStr --> ' + instWrapListStr);
            List<InstallationWrapper> instWrapList = (List<InstallationWrapper>)JSON.deSerialize(instWrapListStr, List<InstallationWrapper>.class);
            List<InstallationWrapper> allInstWrapList = (List<InstallationWrapper>)JSON.deSerialize(allRecsStr, List<InstallationWrapper>.class);
            System.debug('instWrapList --> ' + instWrapList);
            List<Installation__c> instList = new List<Installation__c>();
            for(InstallationWrapper instWrap : instWrapList)
            {
                Installation__c inst = new Installation__c(Id = instWrap.InstId,
                                        Installation_Type__c = instType
                                        );
                System.debug('instType --> ' + instType);
                System.debug('inst_Type --> ' + inst.Installation_Type__c);
                if(inst.Installation_Type__c == 'Vessel')
                {
                    inst.Vessel_Name__c = vesselType;
                }
                else
                {
                    inst.Organisation_Name__c = orgType;
                }
                inst.Delivery_Contact__c = delvCont;
                inst.Invoice_Account__c = invAcc;
                inst.Client__c = client;
                System.debug('inst --> ' + inst);
                instList.add(inst);
                
            }
            if(!instList.isEmpty())
            {
                update instList;
                for(Installation__c inst : [SELECT Id, Name, Delivery_Contact__c, Delivery_Contact__r.Name, Client__c, Client__r.Name, Invoice_Account__c, Invoice_Account__r.Name, Vessel_Name__c, Vessel_Name__r.Name, Organisation_Name__c, Organisation_Name__r.Name, Installation_Type__c FROM Installation__c WHERE Id IN :instList])
                {
                    for(InstallationWrapper instWrapRec : allInstWrapList)
                    {
                        if(inst.Id == instWrapRec.instId)
                        {
                            instWrapRec.InstallationType = inst.Installation_Type__c;
                            instWrapRec.vesselName = inst.Vessel_Name__r.Name;
                            instWrapRec.OrganisationName = inst.Organisation_Name__r.Name;
                            instWrapRec.VesOrgName = inst.Installation_Type__c == 'Vessel' ? inst.Vessel_Name__r.Name : inst.Organisation_Name__r.Name;
                            instWrapRec.InvAccName = inst.Invoice_Account__c != NULL ? inst.Invoice_Account__r.Name : '';
                            instWrapRec.ClientName = inst.Client__c != NULL ? inst.Client__r.Name : '';
                            instWrapRec.DelvContact = inst.Delivery_Contact__c != NULL ? inst.Delivery_Contact__r.Name : '';
                        }
                    }
                }
            }
            return allInstWrapList;
        }
        catch (Exception e)
        {
            System.debug('e --> ' + e);
            throw new AuraHandledException(e.getMessage());
        }
    }

    public class InstallationWrapper
    {
        public InstallationWrapper(){}

        public InstallationWrapper(Installation__c inst)
        {
            InstId = inst.Id;
            InstName = inst.Name;
            CustomerName = inst.Contract_Customer__r.Name;
            InvAccName = inst.Invoice_Account__c != NULL ? inst.Invoice_Account__r.Name : '';
            ClientName = inst.Client__c != NULL ? inst.Client__r.Name : '';
            DelvContact = inst.Delivery_Contact__c != NULL ? inst.Delivery_Contact__r.Name : '';
            //QuoteName = qtName;
            //QuoteLineGroupName = qlgName;
            InstallationType = inst.Installation_Type__c;
        }

        @AuraEnabled
        public String DelvContact;
        @AuraEnabled
        public String ClientName;
        @AuraEnabled
        public String InvAccName;
        @AuraEnabled
        public String InstId;
        @AuraEnabled
        public String InstName;
        @AuraEnabled
        public String CustomerName;
        @AuraEnabled
        public String QuoteName;
        @AuraEnabled
        public String QuoteLineGroupName;
        @AuraEnabled
        public String VesOrgName;
        @AuraEnabled
        public String VesselName;
        @AuraEnabled
        public String OrganisationName;
        @AuraEnabled
        public String InstallationType;
    }
}