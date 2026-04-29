public with sharing class FutureInstallationTerminationBatch implements Database.Batchable<FutureInstallationTerminationBatch.GroupScope>, Database.AllowsCallouts {
    public class GroupScope {
        public Id contractId;
        public Date terminationDate;

        public GroupScope(Id contractId, Date terminationDate) {
            this.contractId = contractId;
            this.terminationDate = terminationDate;
        }
    }

    public Iterable<GroupScope> start(Database.BatchableContext context) {
        List<String> retryableStatuses = new List<String>{'Requested', 'CPQ Submitted', 'Retry Pending'};
        List<GroupScope> groups = new List<GroupScope>();
        for (AggregateResult result : [
            SELECT Contract__c contractId, Termination_End_Date__c terminationDate
            FROM Installation__c
            WHERE Installation_Order_Status__c = 'Future Terminated'
              AND Termination_End_Date__c <= :Date.today()
              AND Contract__c != null
              AND Termination_End_Date__c != null
              AND (
                  Termination_Process_Status__c = null
                  OR Termination_Process_Status__c IN :retryableStatuses
              )
            GROUP BY Contract__c, Termination_End_Date__c
        ]) {
            groups.add(new GroupScope((Id)result.get('contractId'), (Date)result.get('terminationDate')));
        }
        return groups;
    }

    public void execute(Database.BatchableContext context, List<GroupScope> scope) {
        for (GroupScope groupScope : scope) {
            FutureInstallationTerminationService.processGroup(groupScope.contractId, groupScope.terminationDate);
        }
    }

    public void finish(Database.BatchableContext context) {
    }
}
