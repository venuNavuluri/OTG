public with sharing class InstallationsRenewalBatch implements Database.Batchable<SObject>, Database.Stateful {
    private Set<Id> installationIds;

    public InstallationsRenewalBatch(Set<Id> installationIds) {
        this.installationIds = (installationIds == null) ? new Set<Id>() : new Set<Id>(installationIds);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Contract__r.StartDate, Installation_End_Date__c,
                   Quote_Line_Group__c, Order__c
            FROM Installation__c
            WHERE Id IN :installationIds
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Installation__c> scope) {
        if (scope == null || scope.isEmpty()) {
            return;
        }
        InstallationsRenewalService.processRenewalInstallations(scope);
    }

    public void finish(Database.BatchableContext bc) {
        // No-op
    }
}