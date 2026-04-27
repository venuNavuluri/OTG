public with sharing class ContractTerminationService {
    private static final String INSTALLATION_STATUS_TERMINATED = 'Terminated';

    public static void processInstallations(List<Installation__c> installationScope) {
        if (installationScope == null || installationScope.isEmpty()) {
            return;
        }

        Set<Id> contractIds = new Set<Id>();
        for (Installation__c installationRec : installationScope) {
            if (installationRec.Contract__c != null) {
                contractIds.add(installationRec.Contract__c);
            }
        }
        if (contractIds.isEmpty()) {
            return;
        }

        Map<Id, Contract> contractsById = new Map<Id, Contract>([
            SELECT Id, EndDate, Terminated_Date__c, Lost_Reason__c, Lost_Reason_Comments__c
            FROM Contract
            WHERE Id IN :contractIds
        ]);

        List<Installation__c> installationsToUpdate = new List<Installation__c>();
        for (Installation__c installationRec : installationScope) {
            Contract contractRec = contractsById.get(installationRec.Contract__c);
            if (contractRec == null || contractRec.Terminated_Date__c == null) {
                continue;
            }

            Date terminationDate = contractRec.Terminated_Date__c;
            installationsToUpdate.add(new Installation__c(
                Id = installationRec.Id,
                Installation_Order_Status__c = INSTALLATION_STATUS_TERMINATED,
                Termination_End_Date__c = terminationDate,
                Termination_Reason__c = buildInstallationTerminationReason(contractRec),
                Installation_End_date__c = terminationDate
            ));
        }

        if (!installationsToUpdate.isEmpty()) {
            update installationsToUpdate;
        }
    }

    @TestVisible
    static String buildInstallationTerminationReason(Contract contractRec) {
        List<String> parts = new List<String>();
        parts.add('Contract termination');
        if (!String.isBlank(contractRec.Lost_Reason__c)) {
            parts.add('Lost Reason: ' + contractRec.Lost_Reason__c);
        }
        if (!String.isBlank(contractRec.Lost_Reason_Comments__c)) {
            parts.add('Comments: ' + contractRec.Lost_Reason_Comments__c);
        }
        return String.join(parts, ' | ');
    }
}
