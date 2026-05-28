public with sharing class FutureTermCancelService {
    private static final String STATUS_ACTIVE = 'Active';
    private static final String STATUS_FUTURE_TERMINATED = 'Future Terminated';
    private static final String STATUS_TERMINATED = 'Terminated';
    private static final String PROCESS_STATUS_COMPLETED = 'Completed';
    private static final String ORDER_STATUS_ACTIVATED = 'Activated';

    public class CancelResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id installationId;
    }

    @AuraEnabled
    public static CancelResult cancelFutureTermination(Id installationId) {
        if (installationId == null) {
            throw new AuraHandledException('Installation id is required.');
        }

        Installation__c installation = [
            SELECT Id,
                   Installation_Order_Status__c,
                   Termination_Process_Status__c,
                   Termination_Quote__c,
                   Termination_Quote__r.Installation__c,
                   Termination_Quote__r.Auto_Termination__c,
                   Termination_Order__c,
                   Termination_Order__r.Status
            FROM Installation__c
            WHERE Id = :installationId
            LIMIT 1
        ];

        validateCancellable(installation);

        if (installation.Termination_Quote__c != null) {
            SBQQ__Quote__c quoteUpdate = new SBQQ__Quote__c(
                Id = installation.Termination_Quote__c,
                Auto_Termination__c = false
            );
            if (installation.Termination_Quote__r.Installation__c == installation.Id) {
                quoteUpdate.Installation__c = null;
            }
            update quoteUpdate;
        }

        update new Installation__c(
            Id = installation.Id,
            Installation_Order_Status__c = STATUS_ACTIVE,
            Termination_End_Date__c = null,
            Termination_Reason__c = null,
            Auto_Termination__c = false,
            Termination_Quote__c = null,
            Termination_Order__c = null,
            Termination_Process_Status__c = null,
            Termination_Process_Error__c = null,
            Auto_Installation_Termination_Error__c = null
        );

        CancelResult result = new CancelResult();
        result.success = true;
        result.message = 'Future termination cancelled successfully.';
        result.installationId = installation.Id;
        return result;
    }

    private static void validateCancellable(Installation__c installation) {
        if (installation.Installation_Order_Status__c == STATUS_TERMINATED) {
            throw new AuraHandledException('This installation is already terminated and cannot be cancelled through this action.');
        }

        if (installation.Installation_Order_Status__c != STATUS_FUTURE_TERMINATED) {
            throw new AuraHandledException('Only future terminated installations can be cancelled.');
        }

        if (installation.Termination_Process_Status__c == PROCESS_STATUS_COMPLETED) {
            throw new AuraHandledException('This future termination has already completed and cannot be cancelled through this action.');
        }

        if (installation.Termination_Order__r != null &&
            installation.Termination_Order__r.Status == ORDER_STATUS_ACTIVATED) {
            throw new AuraHandledException('The termination order is already activated. Use the commercial reversal process.');
        }
    }
}
