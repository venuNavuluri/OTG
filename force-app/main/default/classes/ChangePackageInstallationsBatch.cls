/**
 * Batch that finalizes a Change Package after an Order activates.
 * Supports single or multiple Orders in one run.
 *
 * For each Order it:
 *  - derives the activation date once (ActivatedDate -> EffectiveDate -> today),
 *  - finds active installations in "In Progress" change state,
 *  - orchestrates the change-package flow,
 *  - marks installations as Completed.
 *
 * Enqueue examples:
 *   Database.executeBatch(new ChangePackageInstallationsBatch(orderId), 100);
 *   Database.executeBatch(new ChangePackageInstallationsBatch(new Set<Id>{ orderId1, orderId2 }), 100);
 *   ChangePackageInstallationsBatch.enqueue(orderId);                 // default scope
 *   ChangePackageInstallationsBatch.enqueue(new Set<Id>{ ... });     // default scope
 */
public without sharing class ChangePackageInstallationsBatch
    implements Database.Batchable<SObject>, Database.Stateful {

    // --- Configuration ---
    private static final Integer DEFAULT_SCOPE_SIZE = 100;

    // --- Batch state ---
    private final Set<Id> orderIds;                // Orders this batch is for
    private Map<Id, Date> activationDateByOrderId; // Calculated once in start()
    private Integer processedCount = 0;            // Stateful counters for finish() logging
    private Integer updatedCount   = 0;

    /** Backward-compatible constructor (single Order). */
    public ChangePackageInstallationsBatch(Id orderId) {
        this.orderIds = new Set<Id>();
        if (orderId != null) this.orderIds.add(orderId);
    }

    /** New constructor: multiple Orders in a single batch. */
    public ChangePackageInstallationsBatch(Set<Id> orderIds) {
        this.orderIds = new Set<Id>();
        if (orderIds != null) this.orderIds.addAll(orderIds);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Guard for no orders passed
        if (orderIds == null || orderIds.isEmpty()) {
            return Database.getQueryLocator('SELECT Id FROM Installation__c WHERE Id = null');
        }

        activationDateByOrderId = new Map<Id, Date>();

        // Derive activation date per Order (ActivatedDate -> EffectiveDate -> today)
        for (Order o : [
            SELECT Id, ActivatedDate, EffectiveDate
            FROM Order
            WHERE Id IN :orderIds
        ]) {
            Date actDate = (o.EffectiveDate != null) ? o.EffectiveDate : Date.today();
            activationDateByOrderId.put(o.Id, actDate);
        }

        if (activationDateByOrderId.isEmpty()) {
            return Database.getQueryLocator('SELECT Id FROM Installation__c WHERE Id = null');
        }

        // Installations tied to these orders and eligible for change-package processing
        return Database.getQueryLocator([
            SELECT Id, Name, Contract__c, Quote_Line_Group__c, Package__c, Order__c,
                   Contract__r.StartDate, Contract__r.EndDate, Contract__r.Billing_Frequency__c, Contract__r.ContractTerm,
                   Installation_End_Date__c, Installation_Start_Date__c, Invoice_Account__c, CurrencyIsoCode
            FROM Installation__c
            WHERE Order__c IN :activationDateByOrderId.keySet()
              AND Change_Package_Status__c = 'In Progress'
              AND Installation_Order_Status__c = 'Active'
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Installation__c> scope) {
        if (scope == null || scope.isEmpty()) return;

        try {
            // Group installations by Order
            Map<Id, List<Installation__c>> installsByOrder = new Map<Id, List<Installation__c>>();
            for (Installation__c inst : scope) {
                if (inst.Order__c == null) continue;
                if (!installsByOrder.containsKey(inst.Order__c)) {
                    installsByOrder.put(inst.Order__c, new List<Installation__c>());
                }
                installsByOrder.get(inst.Order__c).add(inst);
            }

            // Process each Order group with its activation date
            for (Id ordId : installsByOrder.keySet()) {
                Date actDate = activationDateByOrderId != null && activationDateByOrderId.containsKey(ordId)
                    ? activationDateByOrderId.get(ordId)
                    : Date.today(); // defensive fallback

                List<Installation__c> orderInstalls = installsByOrder.get(ordId);

                // Orchestrate change-package work for this order's installations
                InstallationsChangePackageService.process(orderInstalls, actDate);

                // Mark as Completed
                List<Installation__c> toUpdate = new List<Installation__c>();
                for (Installation__c installation : orderInstalls) {
                    toUpdate.add(new Installation__c(
                        Id = installation.Id,
                        Change_Package_Status__c = 'Completed'
                    ));
                }
                if (!toUpdate.isEmpty()) {
                    update toUpdate;
                    updatedCount += toUpdate.size();
                }

                processedCount += orderInstalls.size();
            }

        } catch (Exception ex) {
            Logger.error('ChangePackageInstallationsBatch.execute error: ' + ex.getMessage()
                + ' | line: ' + ex.getLineNumber()
                + ' | stack: ' + ex.getStackTraceString());
            Logger.saveLog();
        }
    }

    public void finish(Database.BatchableContext bc) {
        try {
            Logger.info(
                'ChangePackageInstallationsBatch finished. '
                + 'Orders=' + String.valueOf(orderIds != null ? orderIds.size() : 0)
                + ', processed=' + String.valueOf(processedCount)
                + ', updated=' + String.valueOf(updatedCount)
            );
            Logger.saveLog();
        } catch (Exception ex) {
            // swallow
        }
    }

    // Convenience enqueue (single Order) with default scope
    public static void enqueue(Id orderId) {
        Database.executeBatch(new ChangePackageInstallationsBatch(orderId), DEFAULT_SCOPE_SIZE);
    }

    // Convenience enqueue (multiple Orders) with default scope
    public static void enqueue(Set<Id> orderIds) {
        Database.executeBatch(new ChangePackageInstallationsBatch(orderIds), DEFAULT_SCOPE_SIZE);
    }
}