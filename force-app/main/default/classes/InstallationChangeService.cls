public class InstallationChangeService {
    public class ChangePayload {
        public Id installationId;
        public Id contractId;
        public Id quoteId;
        public Id opportunityId;
        public Id packageId;
        public Id quoteLineGroupId;
        public Id orderId;
        public String changeType;
        public Id oldPackageId;
        public Id newPackageId;
        public Id oldContractId;
        public Id newContractId;
        public Id oldQuoteId;
        public Id newQuoteId;
        public Boolean updateOrderOnly;
    }

    public static void enqueueChanges(List<Installation__c> newList, Map<Id, Installation__c> oldMap) {
        if (newList == null || newList.isEmpty() || oldMap == null || oldMap.isEmpty()) {
            return;
        }

        Set<Id> quoteIds = new Set<Id>();
        for (Installation__c inst : newList) {
            Installation__c oldInst = oldMap.get(inst.Id);
            if (oldInst == null) continue;

            if (inst.Quote__c != null) quoteIds.add(inst.Quote__c);
            if (oldInst.Quote__c != null) quoteIds.add(oldInst.Quote__c);
        }

        Map<Id, SBQQ__Quote__c> quoteMap = quoteIds.isEmpty() ? new Map<Id, SBQQ__Quote__c>() :
            new Map<Id, SBQQ__Quote__c>([
                SELECT Id, SBQQ__Opportunity2__c, SBQQ__Type__c
                FROM SBQQ__Quote__c
                WHERE Id IN :quoteIds
            ]);

        List<ChangePayload> payloads = new List<ChangePayload>();
        for (Installation__c inst : newList) {
            Installation__c oldInst = oldMap.get(inst.Id);
            if (oldInst == null) continue;
            Boolean isRenewalChange = isContractChange(oldInst, inst) && isRenewalQuote(inst, oldInst, quoteMap);
            Boolean isPackageChange = isPackageChangeInProgress(oldInst, inst);
            Boolean isPackageChangeCompleted = isPackageChangeCompletion(oldInst, inst);

            if (!isRenewalChange && isStatusChange(oldInst, inst, 'Active')) {
                payloads.add(buildPayload('Activated', inst, oldInst, quoteMap));
            }

            if (isRenewalChange) {
                ChangePayload renewalPayload = buildPayload('Renewal', inst, oldInst, quoteMap);
                renewalPayload.oldContractId = oldInst.Contract__c;
                renewalPayload.newContractId = inst.Contract__c;
                payloads.add(renewalPayload);
            }

            if (isPackageChange) {
                ChangePayload packagePayload = buildPayload('Package Change', inst, oldInst, quoteMap);
                packagePayload.oldPackageId = oldInst.Package__c;
                packagePayload.newPackageId = inst.Package__c;
                payloads.add(packagePayload);
            }

            if (isPackageChangeCompleted && inst.Order__c != null) {
                ChangePayload completionPayload = buildPayload('Package Change', inst, oldInst, quoteMap);
                completionPayload.updateOrderOnly = true;
                payloads.add(completionPayload);
            }
        }

        if (payloads.isEmpty()) {
            return;
        }

        System.enqueueJob(new InstallationChangeQueueable(payloads));
    }

    private static ChangePayload buildPayload(
        String changeType,
        Installation__c inst,
        Installation__c oldInst,
        Map<Id, SBQQ__Quote__c> quoteMap
    ) {
        ChangePayload payload = new ChangePayload();
        payload.installationId = inst.Id;
        payload.contractId = inst.Contract__c;
        payload.quoteId = inst.Quote__c;
        payload.packageId = inst.Package__c;
        payload.quoteLineGroupId = inst.Quote_Line_Group__c;
        payload.orderId = inst.Order__c != null ? inst.Order__c : oldInst.Order__c;
        payload.changeType = changeType;
        payload.oldPackageId = oldInst.Package__c;
        payload.newPackageId = inst.Package__c;
        payload.oldContractId = oldInst.Contract__c;
        payload.newContractId = inst.Contract__c;
        payload.oldQuoteId = oldInst.Quote__c;
        payload.newQuoteId = inst.Quote__c;

        Id quoteIdForOpp = inst.Quote__c != null ? inst.Quote__c : oldInst.Quote__c;
        if (quoteIdForOpp != null && quoteMap.containsKey(quoteIdForOpp)) {
            payload.opportunityId = quoteMap.get(quoteIdForOpp).SBQQ__Opportunity2__c;
        }

        return payload;
    }

    private static Boolean isStatusChange(Installation__c oldInst, Installation__c inst, String toStatus) {
        return inst.Installation_Order_Status__c == toStatus && oldInst.Installation_Order_Status__c != toStatus;
    }

    private static Boolean isContractChange(Installation__c oldInst, Installation__c inst) {
        return inst.Contract__c != oldInst.Contract__c && inst.Contract__c != null;
    }

    private static Boolean isRenewalQuote(Installation__c inst, Installation__c oldInst, Map<Id, SBQQ__Quote__c> quoteMap) {
        if (inst.Quote__c == null) {
            return false;
        }
        if (!quoteMap.containsKey(inst.Quote__c)) {
            return false;
        }
        return quoteMap.get(inst.Quote__c).SBQQ__Type__c == 'Renewal';
    }

    private static Boolean isPackageChangeInProgress(Installation__c oldInst, Installation__c inst) {
        if (inst.Change_Package_Status__c != 'In Progress') {
            return false;
        }
        if (oldInst.Change_Package_Status__c == 'In Progress') {
            return false;
        }
        return inst.Package__c != oldInst.Package__c;
    }

    private static Boolean isPackageChangeCompletion(Installation__c oldInst, Installation__c inst) {
        if (inst.Change_Package_Status__c != 'Completed') {
            return false;
        }
        return oldInst.Change_Package_Status__c != 'Completed';
    }

    public class InstallationChangeQueueable implements Queueable {
        private final List<ChangePayload> payloads;

        public InstallationChangeQueueable(List<ChangePayload> payloads) {
            this.payloads = payloads == null ? new List<ChangePayload>() : payloads;
        }

        public void execute(QueueableContext context) {
            if (payloads.isEmpty()) return;

            List<Installation_Change__c> recordsToInsert = new List<Installation_Change__c>();
            List<Installation_Change__c> recordsToUpdate = new List<Installation_Change__c>();
            for (ChangePayload payload : payloads) {
                if (payload.updateOrderOnly == true) {
                    Installation_Change__c existing = InstallationChangeService.findLatestPackageChange(payload);
                    if (existing != null && existing.Order__c == null && payload.orderId != null) {
                        existing.Order__c = payload.orderId;
                        recordsToUpdate.add(existing);
                    }
                    continue;
                }
                Installation_Change__c rec = new Installation_Change__c(
                    Installation__c = payload.installationId,
                    Contract__c = payload.contractId,
                    Quote__c = payload.quoteId,
                    Opportunity__c = payload.opportunityId,
                    Package__c = payload.packageId,
                    Quote_Line_Group__c = payload.quoteLineGroupId,
                    Order__c = payload.orderId,
                    // Order__c is set after field recreation to standard Order
                    Change_Type__c = payload.changeType,
                    Change_Date__c = System.now(),
                    Old_Package__c = payload.oldPackageId,
                    New_Package__c = payload.newPackageId,
                    Old_Contract__c = payload.oldContractId,
                    New_Contract__c = payload.newContractId,
                    Old_Quote__c = payload.oldQuoteId,
                    New_Quote__c = payload.newQuoteId
                );
                recordsToInsert.add(rec);
            }

            if (!recordsToInsert.isEmpty()) {
                insert recordsToInsert;
            }
            if (!recordsToUpdate.isEmpty()) {
                update recordsToUpdate;
            }
        }
    }

    private static Installation_Change__c findLatestPackageChange(ChangePayload payload) {
        if (payload == null || payload.installationId == null) return null;
        List<Installation_Change__c> matches = [
            SELECT Id, Order__c, New_Package__c, Package__c
            FROM Installation_Change__c
            WHERE Installation__c = :payload.installationId
              AND Change_Type__c = 'Package Change'
              AND Order__c = null
              AND (New_Package__c = :payload.newPackageId OR Package__c = :payload.packageId)
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return matches.isEmpty() ? null : matches[0];
    }

    public static Installation_Change__c buildChangeRecord(
        String changeType,
        Id installationId,
        Id quoteId,
        Id packageId,
        Id quoteLineGroupId,
        Id contractId,
        Id orderId
    ) {
        if (installationId == null || String.isBlank(changeType)) return null;
        return new Installation_Change__c(
            Installation__c = installationId,
            Contract__c = contractId,
            Quote__c = quoteId,
            Package__c = packageId,
            Quote_Line_Group__c = quoteLineGroupId,
            Order__c = orderId,
            Change_Type__c = changeType,
            Change_Date__c = System.now()
        );
    }
}
