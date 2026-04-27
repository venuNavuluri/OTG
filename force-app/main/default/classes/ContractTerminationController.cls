public with sharing class ContractTerminationController {
    private static final String CONTRACT_STATUS_TERMINATED = 'Terminated';

    @AuraEnabled
    public static void requestTermination(
        Id contractId,
        Date terminationDate,
        String lostReason,
        String lostReasonComments
    ) {
        if (contractId == null) {
            throw new AuraHandledException('Contract Id is required.');
        }
        if (terminationDate == null) {
            throw new AuraHandledException('Termination date is required.');
        }
        if (String.isBlank(lostReason)) {
            throw new AuraHandledException('Lost Reason is required.');
        }
        if (String.isBlank(lostReasonComments)) {
            throw new AuraHandledException('Lost Reason Comments is required.');
        }

        List<Contract> contracts = [
            SELECT Id, Status, StartDate, EndDate
            FROM Contract
            WHERE Id = :contractId
            LIMIT 1
        ];
        if (contracts.isEmpty()) {
            throw new AuraHandledException('Contract not found.');
        }

        Contract contractRec = contracts[0];
        if (contractRec.Status == CONTRACT_STATUS_TERMINATED) {
            throw new AuraHandledException('Contract is already terminated.');
        }
        if (contractRec.StartDate == null || contractRec.EndDate == null) {
            throw new AuraHandledException('Contract start date and end date must be populated before termination.');
        }
        if (terminationDate < contractRec.StartDate || terminationDate > contractRec.EndDate) {
            throw new AuraHandledException('Termination date should be within the contracting period.');
        }

        update new Contract(
            Id = contractId,
            Status = CONTRACT_STATUS_TERMINATED,
            Terminated_Date__c = terminationDate,
            Lost_Reason__c = lostReason,
            Lost_Reason_Comments__c = lostReasonComments
        );

        Database.executeBatch(new ContractTerminationBatch(new Set<Id>{contractId}), 50);
    }
}
