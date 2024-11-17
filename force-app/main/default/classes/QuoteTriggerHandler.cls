/**
* @description       :
* @author            : Venu Navuluri
* @group             :
* @last modified on  : 27-09-2023
* @last modified by  : Venu Navuluri
**/
public class QuoteTriggerHandler extends TriggerHandler {
    public override void beforeInsert() {
        QuoteTriggerHelper.updateQlgCheckbox(Trigger.new);
    }
    public override void afterInsert() {
        createQuoteLineGroups((Map<Id, SBQQ__Quote__c>) Trigger.newMap);
        //QuoteTriggerHandler.createQuoteLineGroupsAsync(Trigger.newMap.keySet());
        QuoteTriggerHelper.createDummyQLG((Map<Id, SBQQ__Quote__c>) Trigger.newMap);
    }
    protected override void afterDelete() {
    }
    
    public override void beforeUpdate() {
        QuoteTriggerHelper.validateInstallationCount(
            (Map<Id, SBQQ__Quote__c>) Trigger.newMap,
            (Map<Id, SBQQ__Quote__c>) Trigger.oldMap
        );
    }
    
    public override void afterUpdate /*Map<Id, SBQQ__Quote__c> newQtMap, Map<Id, SBQQ__Quote__c> oldQtMap*/() {
        createPackageRecords(
            (Map<Id, SBQQ__Quote__c>) Trigger.newMap,
            (Map<Id, SBQQ__Quote__c>) Trigger.oldMap
        );
    }
    
    public void createPackageRecords(
        Map<Id, SBQQ__Quote__c> newQtMap,
        Map<Id, SBQQ__Quote__c> oldQtMap
    )
    {
        try
        {
            System.debug('newQtMap --> ' + newQtMap);
            System.debug('oldQtMap --> ' + oldQtMap);
            Map<Id, Package__c> qlgIdPackToInsertMap = new Map<Id, Package__c>();
            List<Id> qtIdList = new List<Id>();
            
            for (SBQQ__Quote__c qt : newQtMap.values()) {
                if (
                    qt.SBQQ__Type__c == 'Quote' &&
                    (qt.SBQQ__Primary__c &&
                     qt.SBQQ__Status__c == 'Approved' &&
                     oldQtMap.get(qt.Id).SBQQ__Status__c != 'Approved')
                ) {
                    qtIdList.add(qt.Id);
                }
            }
            System.debug('qtIdList --> ' + qtIdList);
            
            if (!qtIdList.isEmpty()) {
                for (SBQQ__QuoteLineGroup__c qlg : [
                    SELECT
                    Id,
                    Name,
                    Installation_Quantity__c,
                    Number_of_Rapid_Titles__c,
                    Number_of_Special_Products__c,
                    Number_of_Virtual_Classrooms__c,
                    User_Quantity__c,
                    SBQQ__Quote__c
                    FROM SBQQ__QuoteLineGroup__c
                    WHERE SBQQ__Quote__c IN :qtIdList
                ]) {
                    Package__c pack = new Package__c(
                        Account__c = newQtMap.get(qlg.SBQQ__Quote__c).SBQQ__Account__c,
                        Contract__c = newQtMap.get(qlg.SBQQ__Quote__c)
                        .SBQQ__MasterContract__c,
                        Installation_Quantity__c = qlg.Installation_Quantity__c,
                        Number_of_Rapid_Titles__c = qlg.Number_of_Rapid_Titles__c,
                        Number_of_Special_Products__c = qlg.Number_of_Special_Products__c,
                        Number_of_Virtual_Classrooms__c = qlg.Number_of_Virtual_Classrooms__c,
                        Package_Name__c = qlg.Name,
                        Name = qlg.Name,
                        User_Quantity__c = qlg.User_Quantity__c,
                        Quote__c = qlg.SBQQ__Quote__c
                    );
                    qlgIdPackToInsertMap.put(qlg.Id, pack);
                }
            }
            System.debug('packToInsert --> ' + qlgIdPackToInsertMap);
            if (!qlgIdPackToInsertMap.isEmpty()) {
                insert qlgIdPackToInsertMap.values();
            }
            List<SBQQ__QuoteLineGroup__c> qlgToUpdate = new List<SBQQ__QuoteLineGroup__c>();
            for (Id qlgId : qlgIdPackToInsertMap.keySet()) {
                SBQQ__QuoteLineGroup__c qlg = new SBQQ__QuoteLineGroup__c(
                    Id = qlgId,
                    Package__c = qlgIdPackToInsertMap.get(qlgId).Id
                );
                qlgToUpdate.add(qlg);
            }
            if (!qlgToUpdate.isEmpty()) {
                update qlgToUpdate;
            }
        }
        catch(Exception ex)
        {
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
        }
    }
    
    /*@future
    public static void createQuoteLineGroupsAsync(Set<Id> qtIdSet)
    {
        try
        {
            QuoteCloneScheduler qsch = new QuoteCloneScheduler();
            qsch.qtIdSet = qtIdSet;
            DateTime dt = DateTime.now().addMinutes(5);
            String jobTime =
                '' +
                dt.second() +
                ' ' +
                dt.minute() +
                ' ' +
                dt.hour() +
                ' ' +
                dt.day() +
                ' ' +
                dt.month() +
                ' ? ' +
                dt.year();
            System.debug('jobTime --> ' + jobTime);
            List<Id> qtIdList = new List<Id>();
            qtIdList.addAll(qtIdSet);
            String jobId = System.schedule(qtIdList[0] + 'Clone Quote', jobTime, qsch);
            //Map<Id, SBQQ__Quote__c> qtMap = new Map<Id, SBQQ__Quote__c>([SELECT Id, Name, SBQQ__Type__c, SBQQ__MasterContract__c, SBQQ__Opportunity2__c FROM SBQQ__Quote__c WHERE Id IN :qtIdSet]);
            //new QuoteTriggerHandler().createQuoteLineGroups(qtMap);
        }
        catch(Exception ex)
        {
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
        }
    }
    */
    
    public void createQuoteLineGroups(Map<Id, SBQQ__Quote__c> newQuoteMap)
    {
        try
        {
            if (newQuoteMap.isEmpty()) {
                return;
            }
            
            Map<Id, Id> quoteIdMap = new Map<Id, Id>();
            Map<Id, Id> contractIdToQuoteIdMap = new Map<Id, Id>();
            Map<Id, Id> opportunityIdToQuoteIdMap = new Map<Id, Id>();
            
            for (SBQQ__Quote__c quote : newQuoteMap.values()) {
                if (quote.SBQQ__Type__c == 'Amendment' && quote.SBQQ__MasterContract__c != null) {
                    contractIdToQuoteIdMap.put(quote.SBQQ__MasterContract__c, quote.Id);
                } else if (quote.SBQQ__Type__c == 'Renewal') {
                    opportunityIdToQuoteIdMap.put(quote.SBQQ__Opportunity2__c, quote.Id);
                }
            }
            
            if (!opportunityIdToQuoteIdMap.isEmpty()) {
                List<Opportunity> opportunities = [
                    SELECT Id, SBQQ__RenewedContract__c
                    FROM Opportunity
                    WHERE Id IN :opportunityIdToQuoteIdMap.keySet()
                ];
                
                for (Opportunity opportunity : opportunities) {
                    contractIdToQuoteIdMap.put(opportunity.SBQQ__RenewedContract__c, opportunityIdToQuoteIdMap.get(opportunity.Id));
                }
            }
            
            
            System.debug('contractIdToQuoteIdMap.keySet() --> ' + contractIdToQuoteIdMap.keySet());
            
            if (!contractIdToQuoteIdMap.isEmpty()) {
                List<Package__c> packages = [
                    SELECT Id, Name, Installation_Quantity__c, Contract__c,Number_of_Special_Products__c,User_Quantity__c,Number_of_Virtual_Classrooms__c
                    FROM Package__c
                    WHERE Contract__c IN :contractIdToQuoteIdMap.keySet()
                ];
                
                Map<Id, List<Package__c>> contractToPackagesMap = new Map<Id, List<Package__c>>();
                for (Package__c packageObj : packages) {
                    if (!contractToPackagesMap.containsKey(packageObj.Contract__c)) {
                        contractToPackagesMap.put(packageObj.Contract__c, new List<Package__c>());
                    }
                    contractToPackagesMap.get(packageObj.Contract__c).add(packageObj);
                }
                List<Package__c> packagesToUpdate = new List<Package__c>();
                List<SBQQ__QuoteLineGroup__c> newQuoteLineGroups = new List<SBQQ__QuoteLineGroup__c>();
                for (Id contractId : contractToPackagesMap.keySet()) {
                    Id quoteId = contractIdToQuoteIdMap.get(contractId);
                    if (quoteId != null && contractToPackagesMap.containsKey(contractId)) {
                        for (Package__c packageObj : contractToPackagesMap.get(contractId)) {
                            SBQQ__QuoteLineGroup__c quoteLineGroup = new SBQQ__QuoteLineGroup__c();
                            quoteLineGroup.SBQQ__Quote__c = quoteId;
                            quoteLineGroup.Name = packageObj.Name;
                            quoteLineGroup.Package__c = packageObj.Id;
                            quoteLineGroup.Installation_Quantity__c = packageObj.Installation_Quantity__c; 
                            quoteLineGroup.User_Quantity__c = packageObj.User_Quantity__c; 
                            newQuoteLineGroups.add(quoteLineGroup);
                            
                            // Update Package record with new Quote ID
                            packageObj.Quote__c = quoteId;
                            packagesToUpdate.add(packageObj);
                        }
                    }
                }
                
                if (!newQuoteLineGroups.isEmpty()) {
                    try {
                        System.debug('newQLG --> ' + newQuoteLineGroups);
                        insert newQuoteLineGroups;
                    } catch (DmlException ex) {
                        // Log exception for further analysis
                        System.debug('Error inserting QuoteLineGroup records: ' + ex.getMessage());
                        System.debug('ex --> ' + ex.getLineNumber());
                        System.debug('test --> ' + ex.getStackTraceString());
                        Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
                    }
                }
                
                if (!packagesToUpdate.isEmpty()) {
                    try {
                        update packagesToUpdate;
                    } catch (DmlException ex) {
                        // Log exception for further analysis
                        System.debug('Error updating Package records: ' + ex.getMessage());
                        Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
                    }
                }
            }
        }
        catch(Exception ex)
        {
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
        }
    }
    
}