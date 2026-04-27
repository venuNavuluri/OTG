public with sharing class ContractTerminationBatch implements Database.Batchable<SObject> {
    private final Set<Id> contractIds;

    public ContractTerminationBatch(Set<Id> contractIds) {
        this.contractIds = contractIds == null ? new Set<Id>() : new Set<Id>(contractIds);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        if (contractIds.isEmpty()) {
            return Database.getQueryLocator('SELECT Id FROM Installation__c WHERE Id = null');
        }

        return Database.getQueryLocator([
            SELECT Id, Contract__c, Installation_Order_Status__c
            FROM Installation__c
            WHERE Contract__c IN :contractIds
              AND Installation_Order_Status__c = 'Active'
        ]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<Installation__c> installations = (List<Installation__c>)scope;
        ContractTerminationService.processInstallations(installations);
    }

    public void finish(Database.BatchableContext bc) {
    }
}
