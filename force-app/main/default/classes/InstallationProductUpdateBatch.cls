public with sharing class InstallationProductUpdateBatch implements Database.Batchable<sObject>, Database.Stateful {
    
    private Set<Id> orderIds;
    
    public InstallationProductUpdateBatch(Set<Id> orderIds) {
        this.orderIds = (orderIds == null) ? new Set<Id>() : new Set<Id>(orderIds);
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name, Type, EffectiveDate, SBQQ__Quote__c, SBQQ__Quote__r.SBQQ__MasterContract__c
            FROM Order
            WHERE Id IN :orderIds
              AND SBQQ__Quote__r.SBQQ__MasterContract__c != NULL
              AND Type = 'Amendment'
        ]);
    }
    
    public void execute(Database.BatchableContext bc, List<Order> scope) {
        if (scope == null || scope.isEmpty()) {
            return;
        }

        for (Order ord : scope) {
            if (ord == null || ord.Id == null) {
                continue;
            }

            Set<Id> singleOrderIdSet = new Set<Id>{ord.Id};

            Map<Id, InstallationProductUpdateService.PackageGroup> packageGroups =
                InstallationProductUpdateService.processOrders(singleOrderIdSet);

            InstallationProductUpdateService.createInstallationLinesFromSubscriptions(packageGroups);
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        // Optional: Add any post-processing logic here
        // For example, sending notifications or logging completion
    }
    
    // Override the getBatchSize method to ensure batch size is 1
    public Integer getBatchSize(Database.BatchableContext bc) {
        return 1;
    }
}