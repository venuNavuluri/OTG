/**
 * @description       : 
 * @author            : Venu Navuluri
 * @group             : 
 * @last modified on  : 20-09-2023
 * @last modified by  : Venu Navuluri
**/
public class QuoteTriggerHandler extends TriggerHandler
{
    public override void beforeInsert()
    {
        QuoteTriggerHelper.updateQlgCheckbox(Trigger.new);
    }
    public override void afterInsert()
    {
        //createQuoteLineGroups((Map<Id, SBQQ__Quote__c>)Trigger.newMap);
        QuoteTriggerHandler.createQuoteLineGroupsAsync(Trigger.newMap.keySet());
        QuoteTriggerHelper.createDummyQLG((Map<Id, SBQQ__Quote__c>)Trigger.newMap);
    }
    protected override void afterDelete() {
        
    }
    public override void afterUpdate(/*Map<Id, SBQQ__Quote__c> newQtMap, Map<Id, SBQQ__Quote__c> oldQtMap*/)
    {
        createPackageRecords((Map<Id, SBQQ__Quote__c>)Trigger.newMap, (Map<Id, SBQQ__Quote__c>)Trigger.oldMap);
    }
    
    public void createPackageRecords(Map<Id, SBQQ__Quote__c> newQtMap, Map<Id, SBQQ__Quote__c> oldQtMap)
    {
        System.debug('newQtMap --> ' + newQtMap);
        System.debug('oldQtMap --> ' + oldQtMap);
        Map<Id, Package__c> qlgIdPackToInsertMap = new Map<Id, Package__c>();
        List<Id> qtIdList = new List<Id>();
        for(SBQQ__Quote__c qt : newQtMap.values())
        {
            if(qt.SBQQ__Type__c == 'Quote' && (qt.SBQQ__Primary__c && !oldQtMap.get(qt.Id).SBQQ__Primary__c && qt.SBQQ__Status__c == 'Approved') || (qt.SBQQ__Primary__c && qt.SBQQ__Status__c == 'Approved' && oldQtMap.get(qt.Id).SBQQ__Status__c != 'Approved'))
            {
                qtIdList.add(qt.Id);
            }
        }
        System.debug('qtIdList --> ' + qtIdList);
        if(!qtIdList.isEmpty())
        {
            for(SBQQ__QuoteLineGroup__c qlg : [SELECT Id, Name, Installation_Quantity__c, SBQQ__Quote__c FROM SBQQ__QuoteLineGroup__c WHERE SBQQ__Quote__c IN :qtIdList])
            {
                Package__c pack = new Package__c(Account__c = newQtMap.get(qlg.SBQQ__Quote__c).SBQQ__Account__c,
                                                Contract__c = newQtMap.get(qlg.SBQQ__Quote__c).SBQQ__MasterContract__c,
                                                Installation_Quantity__c = qlg.Installation_Quantity__c,
                                                Quote__c = qlg.SBQQ__Quote__c
                                               );
                qlgIdPackToInsertMap.put(qlg.Id, pack);
            }
        }
        System.debug('packToInsert --> ' + qlgIdPackToInsertMap);
        if(!qlgIdPackToInsertMap.isEmpty())
        {
            insert qlgIdPackToInsertMap.values();
        }
        List<SBQQ__QuoteLineGroup__c> qlgToUpdate = new List<SBQQ__QuoteLineGroup__c>();
        for(Id qlgId : qlgIdPackToInsertMap.keySet())
        {
            SBQQ__QuoteLineGroup__c qlg = new SBQQ__QuoteLineGroup__c(Id = qlgId, Package__c = qlgIdPackToInsertMap.get(qlgId).Id);
            qlgToUpdate.add(qlg);
        }
        if(!qlgToUpdate.isEmpty())
        {
            update qlgToUpdate;
        }
    }
    
    public static void createQuoteLineGroupsAsync(Set<Id> qtIdSet)
    {
        QuoteCloneScheduler qsch = new QuoteCloneScheduler();
        qsch.qtIdSet = qtIdSet;
        DateTime dt = DateTime.now().addMinutes(5);
        String jobTime = '' + dt.second() + ' ' + dt.minute() + ' ' + dt.hour() + ' ' + dt.day() + ' ' + dt.month() + ' ? ' + dt.year();
        System.debug('jobTime --> ' + jobTime);
        List<Id> qtIdList = new List<Id>();
        qtIdList.addAll(qtIdSet);
        String jobId = System.schedule(qtIdList[0] + 'Clone Quote', jobTime, qsch);
        //Map<Id, SBQQ__Quote__c> qtMap = new Map<Id, SBQQ__Quote__c>([SELECT Id, Name, SBQQ__Type__c, SBQQ__MasterContract__c FROM SBQQ__Quote__c WHERE Id IN :qtIdSet]);
        //new QuoteTriggerHandler().createQuoteLineGroups(qtMap);
    }
    
    public void createQuoteLineGroups(Map<Id, SBQQ__Quote__c> newQtMap)
    {
        Map<Id, Id> qtIdMap = new Map<Id, Id>();
        Map<Id, Id> masterContractIdQtIdMap = new Map<Id, Id>();
        for(SBQQ__Quote__c qt : newQtMap.values())
        {
            if((qt.SBQQ__Type__c == 'Renewal' || qt.SBQQ__Type__c == 'Amendment') && qt.SBQQ__MasterContract__c != NULL)
            {
                masterContractIdQtIdMap.put(qt.SBQQ__MasterContract__c, qt.Id);
            }
        }
        System.debug('masterContractIdQtIdMap --> ' + masterContractIdQtIdMap);
        List<Contract> contractList = [SELECT Id, Name, SBQQ__Quote__c FROM Contract WHERE Id IN :masterContractIdQtIdMap.keySet()];
        for(Contract con : contractList)
        {
            qtIdMap.put(con.SBQQ__Quote__c, masterContractIdQtIdMap.get(con.Id));
        }
        System.debug('qtIdMap --> ' + qtIdMap);
        Map<Id, SBQQ__Quote__c> quoteMap = new Map<Id, SBQQ__Quote__c>([SELECT Id, Name FROM SBQQ__Quote__c WHERE Id IN :qtIdMap.keySet()]);
        List<SBQQ__QuoteLineGroup__c> qlgList = [SELECT Id, Name, Package__c, Installation_Quantity__c, SBQQ__Number__c, SBQQ__ListTotal__c, SBQQ__CustomerTotal__c, SBQQ__NetTotal__c, SBQQ__Quote__c FROM SBQQ__QuoteLineGroup__c WHERE SBQQ__Quote__c IN :qtIdMap.keySet()];
        List<SBQQ__QuoteLine__c> qlList = [SELECT Id, Name, SBQQ__Group__c, SBQQ__Quote__c FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c IN :qtIdMap.keySet()];
        Map<Id, SBQQ__QuoteLine__c> qlNewMap = new Map<Id, SBQQ__QuoteLine__c>([SELECT Id, Name, SBQQ__Group__c, SBQQ__Quote__c FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c IN :qtIdMap.values()]);
        //List<Package__c> packList = [SELECT Id, Name, Quote__c FROM Package__c WHERE Quote__c IN :qtIdMap.values()];
        Map<Id, SBQQ__QuoteLineGroup__c> oldQlgNewQlgMap = new Map<Id, SBQQ__QuoteLineGroup__c>();
        List<SBQQ__QuoteLine__c> qlNewList = new List<SBQQ__QuoteLine__c>();
        
        for(SBQQ__QuoteLineGroup__c qlg : qlgList)
        {
            SBQQ__QuoteLineGroup__c qlgNew = qlg.clone(false, true, false, false);
            qlgNew.SBQQ__Quote__c = qtIdMap.get(qlg.SBQQ__Quote__c);
            oldQlgNewQlgMap.put(qlg.Id, qlgNew);
        }
        System.debug('oldQlgNewQlgMap --> ' + oldQlgNewQlgMap);
        
        if(!oldQlgNewQlgMap.isEmpty())
        {
            insert oldQlgNewQlgMap.values();
        }
        
        /*for(SBQQ__QuoteLine__c ql : qlList)
        {
            SBQQ__QuoteLine__c qlNew = qlNewMap.get(qtIdMap.get(ql.SBQQ__Quote__c));
            System.debug('oldQlgNewQlgMap.get(ql.SBQQ__Group__c) --> ' + oldQlgNewQlgMap.get(ql.SBQQ__Group__c));
            qlNew.SBQQ__Group__c = oldQlgNewQlgMap.get(ql.SBQQ__Group__c).Id;
            qlNewList.add(qlNew);
        }
        System.debug('qlNewList --> ' + qlNewList);
        if(!qlNewList.isEmpty())
        {
            update qlNewList;
        }*/
    }
}