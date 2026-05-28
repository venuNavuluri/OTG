public with sharing class FutureInstallationTerminationService {
    private static final String STATUS_FUTURE_TERMINATED = 'Future Terminated';
    private static final String STATUS_TERMINATED = 'Terminated';
    private static final String PROCESS_STATUS_REQUESTED = 'Requested';
    private static final String PROCESS_STATUS_CPQ_SUBMITTED = 'CPQ Submitted';
    private static final String PROCESS_STATUS_WAITING_FOR_ORDER = 'Waiting For Order Activation';
    private static final String PROCESS_STATUS_COMPLETED = 'Completed';
    private static final String PROCESS_STATUS_FAILED = 'Failed';
    private static final String PROCESS_STATUS_RETRY_PENDING = 'Retry Pending';
    private static final Integer MAX_ATTEMPTS = 6;
    private static final Integer RETRY_DELAY_MINUTES = 3;

    @TestVisible
    private static Map<Id, Id> testQuoteIdsByContract = new Map<Id, Id>();

    public static void processGroup(Id contractId, Date terminationDate) {
        if (contractId == null || terminationDate == null) {
            return;
        }

        List<Installation__c> installations = getEligibleInstallations(contractId, terminationDate);
        if (installations.isEmpty()) {
            return;
        }

        Contract contractRec = installations[0].Contract__r;
        if (contractRec != null && contractRec.EndDate == terminationDate) {
            completeContractEndTerminations(installations);
            return;
        }

        List<Installation__c> validInstallations = markInvalidInstallations(installations);
        if (validInstallations.isEmpty()) {
            return;
        }

        Id quoteId = createAmendmentQuote(contractId, terminationDate);
        if (quoteId == null) {
            setRetryState(validInstallations, null, 'Awaiting grouped amendment quote creation.');
            scheduleRetry(contractId, terminationDate, null, 1);
            return;
        }

        processAmendmentQuote(contractId, terminationDate, quoteId, 1);
    }

    public static void processAmendmentQuote(Id contractId, Date terminationDate, Id quoteId, Integer attempt) {
        if (contractId == null || terminationDate == null || quoteId == null) {
            return;
        }

        List<Installation__c> installations = getEligibleInstallations(contractId, terminationDate);
        List<Installation__c> validInstallations = markInvalidInstallations(installations);
        if (validInstallations.isEmpty()) {
            return;
        }

        Contract contractRec = validInstallations[0].Contract__r;
        try {
            stampTerminationQuote(quoteId, validInstallations[0].Id, terminationDate, contractRec);
        } catch (Exception ex) {
            markFailed(validInstallations, 'Unable to update grouped amendment quote: ' + ex.getMessage());
            return;
        }

        Set<Id> packageIds = new Set<Id>();
        Map<Id, Integer> reductionByPackage = new Map<Id, Integer>();
        for (Installation__c inst : validInstallations) {
            packageIds.add(inst.Package__c);
            Integer count = reductionByPackage.containsKey(inst.Package__c) ? reductionByPackage.get(inst.Package__c) : 0;
            reductionByPackage.put(inst.Package__c, count + 1);
        }

        Map<Id, SBQQ__QuoteLineGroup__c> qlgByPackage = new Map<Id, SBQQ__QuoteLineGroup__c>();
        for (SBQQ__QuoteLineGroup__c qlg : [
            SELECT Id, Package__c, Installation_Quantity__c
            FROM SBQQ__QuoteLineGroup__c
            WHERE SBQQ__Quote__c = :quoteId
              AND Package__c IN :packageIds
        ]) {
            qlgByPackage.put(qlg.Package__c, qlg);
        }

        Set<Id> missingPackageIds = new Set<Id>(packageIds);
        missingPackageIds.removeAll(qlgByPackage.keySet());
        if (!missingPackageIds.isEmpty()) {
            String message = 'Awaiting grouped amendment quote line groups for ' + String.valueOf(missingPackageIds.size()) + ' package(s).';
            setRetryState(validInstallations, quoteId, message);
            if (attempt < MAX_ATTEMPTS) {
                scheduleRetry(contractId, terminationDate, quoteId, attempt + 1);
            } else {
                markFailed(validInstallations, 'Unable to update grouped amendment quote. Quote line groups are not available yet.');
            }
            return;
        }

        List<SBQQ__QuoteLineGroup__c> qlgsToUpdate = new List<SBQQ__QuoteLineGroup__c>();
        for (Id packageId : reductionByPackage.keySet()) {
            SBQQ__QuoteLineGroup__c qlg = qlgByPackage.get(packageId);
            Decimal currentQuantity = qlg.Installation_Quantity__c == null ? 0 : qlg.Installation_Quantity__c;
            Decimal newQuantity = currentQuantity - reductionByPackage.get(packageId);
            if (newQuantity < 0) {
                markFailed(validInstallations, 'Grouped termination cannot reduce amendment quote line group quantity below zero.');
                return;
            }
            qlg.Installation_Quantity__c = newQuantity;
            qlgsToUpdate.add(qlg);
        }

        if (!qlgsToUpdate.isEmpty()) {
            update qlgsToUpdate;
        }

        List<Installation__c> installsToUpdate = new List<Installation__c>();
        for (Installation__c inst : validInstallations) {
            installsToUpdate.add(new Installation__c(
                Id = inst.Id,
                Quote__c = quoteId,
                Quote_Line_Group__c = qlgByPackage.get(inst.Package__c).Id,
                Termination_Quote__c = quoteId,
                Termination_Process_Status__c = PROCESS_STATUS_WAITING_FOR_ORDER,
                Termination_Process_Error__c = null,
                Auto_Installation_Termination_Error__c = null
            ));
        }
        update installsToUpdate;
    }

    private static List<Installation__c> getEligibleInstallations(Id contractId, Date terminationDate) {
        List<String> retryableStatuses = new List<String>{
            PROCESS_STATUS_REQUESTED,
            PROCESS_STATUS_CPQ_SUBMITTED,
            PROCESS_STATUS_RETRY_PENDING
        };
        return [
            SELECT Id, Contract__c, Contract__r.EndDate, Contract__r.Billing_Frequency__c,
                   Package__c, Termination_End_Date__c, Termination_Process_Status__c
            FROM Installation__c
            WHERE Contract__c = :contractId
              AND Termination_End_Date__c = :terminationDate
              AND Installation_Order_Status__c = :STATUS_FUTURE_TERMINATED
              AND (
                  Termination_Process_Status__c = null
                  OR Termination_Process_Status__c IN :retryableStatuses
              )
        ];
    }

    private static void completeContractEndTerminations(List<Installation__c> installations) {
        List<Installation__c> updates = new List<Installation__c>();
        for (Installation__c inst : installations) {
            updates.add(new Installation__c(
                Id = inst.Id,
                Installation_Order_Status__c = STATUS_TERMINATED,
                Installation_End_date__c = inst.Termination_End_Date__c,
                Termination_Process_Status__c = PROCESS_STATUS_COMPLETED,
                Termination_Process_Error__c = null,
                Auto_Installation_Termination_Error__c = null
            ));
        }
        update updates;
    }

    private static List<Installation__c> markInvalidInstallations(List<Installation__c> installations) {
        List<Installation__c> validInstallations = new List<Installation__c>();
        List<Installation__c> invalidUpdates = new List<Installation__c>();
        for (Installation__c inst : installations) {
            if (inst.Package__c == null) {
                invalidUpdates.add(new Installation__c(
                    Id = inst.Id,
                    Termination_Process_Status__c = PROCESS_STATUS_FAILED,
                    Termination_Process_Error__c = 'Future termination cannot proceed because the installation has no related package.',
                    Auto_Installation_Termination_Error__c = 'Future termination cannot proceed because the installation has no related package.'
                ));
            } else {
                validInstallations.add(inst);
            }
        }
        if (!invalidUpdates.isEmpty()) {
            update invalidUpdates;
        }
        return validInstallations;
    }

    private static Id createAmendmentQuote(Id contractId, Date terminationDate) {
        if (Test.isRunningTest() && testQuoteIdsByContract.containsKey(contractId)) {
            return testQuoteIdsByContract.get(contractId);
        }

        try {
            ContractAmenderHelper helper = new ContractAmenderHelper();
            ContractAmenderHelper.QuoteModel quoteModel = helper.load(contractId, true);
            Id quoteId = quoteModel != null ? quoteModel.Id : null;
            return quoteId != null ? quoteId : findExistingAmendmentQuote(contractId, terminationDate);
        } catch (Exception ex) {
            Logger.error('FutureInstallationTerminationService.createAmendmentQuote failed: ' + ex.getMessage());
            Logger.saveLog();
            return findExistingAmendmentQuote(contractId, terminationDate);
        }
    }

    private static Id findExistingAmendmentQuote(Id contractId, Date terminationDate) {
        List<SBQQ__Quote__c> quotes = [
            SELECT Id
            FROM SBQQ__Quote__c
            WHERE SBQQ__MasterContract__c = :contractId
              AND SBQQ__Type__c = 'Amendment'
              AND SBQQ__Ordered__c = false
              AND SBQQ__StartDate__c = :terminationDate
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return quotes.isEmpty() ? null : quotes[0].Id;
    }

    private static void stampTerminationQuote(Id quoteId, Id primaryInstallationId, Date terminationDate, Contract contractRec) {
        SBQQ__Quote__c quoteUpdate = new SBQQ__Quote__c(
            Id = quoteId,
            Auto_Termination__c = true,
            Installation__c = primaryInstallationId,
            SBQQ__StartDate__c = terminationDate
        );
        if (contractRec != null) {
            quoteUpdate.SBQQ__EndDate__c = contractRec.EndDate;
            quoteUpdate.SBQQ__BillingFrequency__c = contractRec.Billing_Frequency__c;
        }
        update quoteUpdate;
    }

    private static void setRetryState(List<Installation__c> installations, Id quoteId, String message) {
        List<Installation__c> updates = new List<Installation__c>();
        for (Installation__c inst : installations) {
            Installation__c updateRec = new Installation__c(
                Id = inst.Id,
                Termination_Process_Status__c = PROCESS_STATUS_RETRY_PENDING,
                Termination_Process_Error__c = message,
                Auto_Installation_Termination_Error__c = message
            );
            if (quoteId != null) {
                updateRec.Termination_Quote__c = quoteId;
            }
            updates.add(updateRec);
        }
        update updates;
    }

    private static void markFailed(List<Installation__c> installations, String message) {
        List<Installation__c> updates = new List<Installation__c>();
        for (Installation__c inst : installations) {
            updates.add(new Installation__c(
                Id = inst.Id,
                Termination_Process_Status__c = PROCESS_STATUS_FAILED,
                Termination_Process_Error__c = message,
                Auto_Installation_Termination_Error__c = message
            ));
        }
        update updates;
    }

    private static void scheduleRetry(Id contractId, Date terminationDate, Id quoteId, Integer attempt) {
        if (Test.isRunningTest()) {
            if (attempt <= 2) {
                System.enqueueJob(new GroupedTerminationPostProcessorQueueable(contractId, terminationDate, quoteId, attempt));
            }
            return;
        }

        Datetime runAt = System.now().addMinutes(RETRY_DELAY_MINUTES);
        String cron = String.valueOf(runAt.second()) + ' ' +
            String.valueOf(runAt.minute()) + ' ' +
            String.valueOf(runAt.hour()) + ' ' +
            String.valueOf(runAt.day()) + ' ' +
            String.valueOf(runAt.month()) + ' ? ' +
            String.valueOf(runAt.year());
        String jobName = 'GroupedTerminationRetry_' + String.valueOf(contractId) + '_' + String.valueOf(Math.abs(Crypto.getRandomLong()));
        System.schedule(jobName, cron, new GroupedTerminationPostProcessorScheduler(contractId, terminationDate, quoteId, attempt));
    }

    public class GroupedTerminationPostProcessorQueueable implements Queueable, Database.AllowsCallouts {
        private Id contractId;
        private Date terminationDate;
        private Id quoteId;
        private Integer attempt;

        public GroupedTerminationPostProcessorQueueable(Id contractId, Date terminationDate, Id quoteId, Integer attempt) {
            this.contractId = contractId;
            this.terminationDate = terminationDate;
            this.quoteId = quoteId;
            this.attempt = attempt == null ? 1 : attempt;
        }

        public void execute(QueueableContext context) {
            Id localQuoteId = quoteId;
            if (localQuoteId == null) {
                localQuoteId = createAmendmentQuote(contractId, terminationDate);
            }
            processAmendmentQuote(contractId, terminationDate, localQuoteId, attempt);
        }
    }

    public class GroupedTerminationPostProcessorScheduler implements Schedulable, Database.AllowsCallouts {
        private Id contractId;
        private Date terminationDate;
        private Id quoteId;
        private Integer attempt;

        public GroupedTerminationPostProcessorScheduler(Id contractId, Date terminationDate, Id quoteId, Integer attempt) {
            this.contractId = contractId;
            this.terminationDate = terminationDate;
            this.quoteId = quoteId;
            this.attempt = attempt == null ? 1 : attempt;
        }

        public void execute(SchedulableContext context) {
            System.enqueueJob(new GroupedTerminationPostProcessorQueueable(contractId, terminationDate, quoteId, attempt));
        }
    }
}
