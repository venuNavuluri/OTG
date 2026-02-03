public class ContractTriggerHandler {

    public static void onBeforeInsert() {
        updatePreviousContract((List<Contract>)Trigger.new);
    }

    public static void onBeforeUpdate() {
        updatePreviousContract((List<Contract>)Trigger.new);
    }

    public static void onAfterInsert() {
        enqueueMetricsIfCpq((Map<Id, Contract>)Trigger.newMap, null);
        updateContractDetails((Map<Id, Contract>)Trigger.newMap);
        updateNextContract((Map<Id, Contract>)Trigger.newMap);
    }
    
    private static Boolean suppressMetricsRecalc = false;

    public static void onAfterUpdate() {
        enqueueMetricsIfCpq((Map<Id, Contract>)Trigger.newMap, (Map<Id, Contract>)Trigger.oldMap);
        activateContracts((Map<Id, Contract>)Trigger.newMap, (Map<Id, Contract>)Trigger.oldMap);
    }

    // Enqueue metrics recalculation only for CPQ contracts with a quote and non-terminated status.
    public static void enqueueMetricsIfCpq(Map<Id, Contract> newMap, Map<Id, Contract> oldMap) {
        Set<Id> contractIdsToRecalc = new Set<Id>();
        for (Contract updated : newMap.values()) {
            if (updated == null || updated.Id == null) continue;
            if (updated.Status != null && updated.Status.equalsIgnoreCase('Terminated')) continue;
            if (updated.SBQQ__Quote__c == null) continue; // skip when quote is blank
            Contract oldRec = oldMap != null ? oldMap.get(updated.Id) : null;
            Boolean isCpq =
                (updated.Subscription_System__c != null && updated.Subscription_System__c.equalsIgnoreCase('Salesforce CPQ')) ||
                (oldRec != null && oldRec.Subscription_System__c != null && oldRec.Subscription_System__c.equalsIgnoreCase('Salesforce CPQ'));
            if (!isCpq) continue; // only recalc for CPQ-sourced contracts
            contractIdsToRecalc.add(updated.Id);
        }
        if (!contractIdsToRecalc.isEmpty() && !suppressMetricsRecalc) {
            enqueueContractMetricsRecalc(contractIdsToRecalc);
        }
    }

    /**
     * Activates contracts and processes related installations.
     */
    public static void activateContracts(Map<Id, Contract> newContrMap, Map<Id, Contract> oldContrMap) {
        try {
            if (newContrMap == null || newContrMap.isEmpty()) {
                return;
            }

            // Maintain previous/next contract relationships regardless of activation
            updateNextContract(newContrMap);

            Set<Id> activationCandidates = new Set<Id>();
            for (Contract newContr : newContrMap.values()) {
                if (newContr == null || newContr.Id == null) {
                    continue;
                }
                Contract oldContr = oldContrMap != null ? oldContrMap.get(newContr.Id) : null;
                Boolean newActivated = newContr.Status != null && newContr.Status.equalsIgnoreCase('Activated');
                Boolean oldActivated = oldContr != null && oldContr.Status != null && oldContr.Status.equalsIgnoreCase('Activated');
                if (newActivated && !oldActivated) {
                    activationCandidates.add(newContr.Id);
                }
            }

            if (activationCandidates.isEmpty()) {
                return;
            }


            Map<Id, Contract> queriedContracts = new Map<Id, Contract>([
                SELECT Id, Status, SBQQ__Quote__c, SBQQ__Quote__r.SBQQ__Type__c, Previous_Contract__c ,Subscription_System__c
                FROM Contract
                WHERE Id IN :activationCandidates
            ]);

            List<Id> renewalContracts = new List<Id>();
            for (Contract contr : queriedContracts.values()) {
                if (contr.SBQQ__Quote__r != null && contr.SBQQ__Quote__r.SBQQ__Type__c == 'Renewal') {
                    renewalContracts.add(contr.Id);
                }
            }

            if (renewalContracts.isEmpty()) {
                return;
            }

            List<Installation__c> instList = [
                SELECT Id, Name, Contract__c, Contract__r.SBQQ__Quote__r.SBQQ__Type__c, 
                       Contract__r.StartDate, Contract__r.EndDate, 
                       Order__c, Order__r.SBQQ__Quote__c, 
                       Quote_Line_Group__r.SBQQ__Quote__c, Order__r.ActivatedDate
                FROM Installation__c 
                WHERE Contract__c IN :renewalContracts 
                AND Installation_Order_Status__c = 'Active'
                ORDER BY CreatedDate DESC
            ];

            if (!instList.isEmpty()) {
                activateInstallations(instList);
            }
        } catch (Exception ex) {
            Logger.error('Error in activateContracts: ' + ex.getMessage() + '\n' + ex.getLineNumber() + '\n' + ex.getStackTraceString());
        } finally {
            Logger.saveLog();
        }
    }

   public static void updatePreviousContract(List<Contract> newContrList) {
    try {        
        Set<Id> quoteIds = new Set<Id>();
        Set<Id> opportunityIds = new Set<Id>();

        // Step 1: Collect Quote and Opportunity IDs
        for (Contract con : newContrList) {
            if (con.SBQQ__Quote__c != null && con.SBQQ__Opportunity__c != null && con.Previous_Contract__c == null) {
                quoteIds.add(con.SBQQ__Quote__c);
                opportunityIds.add(con.SBQQ__Opportunity__c);
            }
        }

        if (quoteIds.isEmpty() || opportunityIds.isEmpty()) {
            return; // No relevant contracts to update
        }

        // Step 2: Bulk Fetch Quotes
        Map<Id, SBQQ__Quote__c> quoteMap = new Map<Id, SBQQ__Quote__c>(
            [SELECT Id, SBQQ__Type__c, Agreement_Type__c, SBQQ__BillingFrequency__c, Total_Installations__c
             FROM SBQQ__Quote__c WHERE Id IN :quoteIds]
        );

        // Step 3: Bulk Fetch Opportunities
        Map<Id, Opportunity> opportunityMap = new Map<Id, Opportunity>(
            [SELECT Id, Name, SBQQ__RenewedContract__c, Legal_Entity__c, Number_of_Installations__c, Business_Unit__c,AgreementType__c,
              Customer_Signed_By__c, Contract_Agreement_Signed_Date__c, Company_Signed_By__c, Company_Signed_Date__c, Contact_Name__r.Job_Title__c,Customer_Signed_By__r.Job_Title__c,
                    SBQQ__RenewedContract__r.Subscription_System__c, 
                    SBQQ__RenewedContract__r.Agreement_Type__c,
                    SBQQ__RenewedContract__r.Next_Renewal_Date__c,
                    SBQQ__RenewedContract__r.Renewal_Month__c,
                    SBQQ__RenewedContract__r.ActivatedDate,
                    SBQQ__RenewedContract__r.Agreement_ID__c,
                    SBQQ__RenewedContract__r.Original_Fixed_Term_Start_Date__c,
                    SBQQ__RenewedContract__r.Original_Fixed_Term_End_Date__c,
                    SBQQ__RenewedContract__r.Original_Fixed_Term__c,
                    SBQQ__RenewedContract__r.Subscription_Value__c,
             		SBQQ__RenewedContract__r.SBQQ__RenewalUpliftRate__c,
                    SBQQ__PrimaryQuote__c, 
                    SBQQ__PrimaryQuote__r.SBQQ__DeliveryMethod__c,
                    SBQQ__PrimaryQuote__r.SBQQ__StartDate__c, 
                    SBQQ__PrimaryQuote__r.SBQQ__EndDate__c,
             		SBQQ__PrimaryQuote__r.SBQQ__PaymentTerms__c
             FROM Opportunity WHERE Id IN :opportunityIds]
        );

        // Step 4: Modify Trigger.new Directly (No DML Needed in Before Triggers)
        for (Contract con : newContrList) {
            SBQQ__Quote__c quote = quoteMap.get(con.SBQQ__Quote__c);
            Opportunity opp = opportunityMap.get(con.SBQQ__Opportunity__c);

            if (quote != null && opp != null) {
                // Update contract fields directly within before trigger
                con.Legal_Entity__c = opp.Legal_Entity__c;
                con.No_of_Installations__c = quote.Total_Installations__c;
                con.Business_Unit__c = opp.Business_Unit__c;
                con.Unit_of_Measure__c = quote.Agreement_Type__c;
                con.Default_Delivery_Method__c = opp.SBQQ__PrimaryQuote__r.SBQQ__DeliveryMethod__c;
                con.Billing_Frequency__c = quote.SBQQ__BillingFrequency__c;
                con.CustomerSignedId = opp.Customer_Signed_By__c; 
                con.CustomerSignedDate = opp.Contract_Agreement_Signed_Date__c; 
                con.CompanySignedId = opp.Company_Signed_By__c;
                con.CompanySignedDate = opp.Company_Signed_Date__c;
                con.CustomerSignedTitle = opp.Customer_Signed_By__r.Job_Title__c;
                con.Agreement_Type__c = opp.AgreementType__c;
                con.Payment_Terms__c = opp.SBQQ__PrimaryQuote__r.SBQQ__PaymentTerms__c;
                con.Subscription_System__c = 'Salesforce CPQ'; // Added on 26-05-2025

                // Handle Renewal Contracts
                if (quote.SBQQ__Type__c == 'Renewal') {
                    con.StartDate = opp.SBQQ__PrimaryQuote__r.SBQQ__StartDate__c;
                    con.EndDate = opp.SBQQ__PrimaryQuote__r.SBQQ__EndDate__c;
                    con.Previous_Contract__c = opp.SBQQ__RenewedContract__c;
                    System.debug('con.Previous_Contract__c --------'+ con.Previous_Contract__c);
                    con.Subscription_System__c = opp.SBQQ__RenewedContract__r.Subscription_System__c;
                    con.Agreement_Type__c = opp.SBQQ__RenewedContract__r.Agreement_Type__c;
                    con.Next_Renewal_Date__c = opp.SBQQ__RenewedContract__r.Next_Renewal_Date__c;
                    //con.SBQQ__RenewalUpliftRate__c = 0;
                    system.debug('con.SBQQ__RenewalUpliftRate__c' + con.SBQQ__RenewalUpliftRate__c);
                    //con.Agreement_ID__c = opp.SBQQ__RenewedContract__r.Agreement_ID__c;
                    con.Original_Fixed_Term_Start_Date__c = opp.SBQQ__RenewedContract__r.Original_Fixed_Term_Start_Date__c;
                    con.Original_Fixed_Term_End_Date__c = opp.SBQQ__RenewedContract__r.Original_Fixed_Term_End_Date__c;
                    con.Original_Fixed_Term__c = opp.SBQQ__RenewedContract__r.Original_Fixed_Term__c;
                    con.Subscription_Value__c = opp.SBQQ__RenewedContract__r.Subscription_Value__c;
                    con.Payment_Terms__c = opp.SBQQ__RenewedContract__r.Payment_Terms__c;
                }
            }
        }
    } catch (Exception ex) {
        Logger.error(ex.getMessage() + '\n' + ex.getLineNumber() + '\n' + ex.getStackTraceString());
        Logger.saveLog();
    }
}

    public static void updateNextContract(Map<Id, Contract> newContrMap) {
        try {
            if (newContrMap.isEmpty()) {
                return; // Exit early if there's nothing to process
            }

            List<Contract> contractsToUpdate = new List<Contract>();

            for (Contract contr : newContrMap.values()) {
                if (contr.Previous_Contract__c != null) {
                    contractsToUpdate.add(new Contract(
                        Id = contr.Previous_Contract__c,
                        Next_Contract__c = contr.Id
                    ));
                }
            }

            if (!contractsToUpdate.isEmpty()) {
                update contractsToUpdate;
            }
        } catch (Exception ex) {
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
        }
    }

    public static void updateContractDetails(Map<Id, Contract> contractMap) {
        
        try {
            if (contractMap.isEmpty()) {
                return; 
            }

            // Step 1: Collect Quote ID to Contract ID mapping
            Map<Id, Id> quoteToContractMap = new Map<Id, Id>();
            for (Contract contract : contractMap.values()) {
                if (contract.SBQQ__Quote__c != null && !contract.Migrated_Contract__c) {
                    quoteToContractMap.put(contract.SBQQ__Quote__c, contract.Id);
                }
            }

            if (quoteToContractMap.isEmpty()) {
                return; // Exit early if there are no quotes associated with the contracts
            }

            // Step 2: Retrieve and update Package__c records
            List<Package__c> packageList = [
                SELECT Id, Contract__c, Quote__c 
                FROM Package__c 
                WHERE Quote__c IN :quoteToContractMap.keySet() AND Installation_Quantity__c > 0
            ];

            for (Package__c packageRecord : packageList) {
                packageRecord.Contract__c = quoteToContractMap.get(packageRecord.Quote__c);
            }

            if (!packageList.isEmpty()) {
                update packageList;
            }

            // Step 3: Retrieve and update Installation__c records
            List<Installation__c> installationList = [
                SELECT Id, Contract__c, Contract__r.SBQQ__Quote__r.SBQQ__Type__c, Package__c, Package__r.Contract__c, CurrencyIsoCode, Subscription_Annual_Order_Value__c,
                Installation_Start_date__c, Installation_End_date__c, Package__r.Quote_Line_Group__c, Contract__r.CurrencyIsoCode, Package__r.InstallationCost__c
                FROM Installation__c 
                WHERE Package__c IN :packageList AND Installation_Order_Status__c != 'Terminated'
            ];
            for (Installation__c installationRecord : installationList) {
                installationRecord.Contract__c = installationRecord.Package__r.Contract__c;
                installationRecord.Quote_Line_Group__c = installationRecord.Package__r.Quote_Line_Group__c;
                installationRecord.CurrencyIsoCode = installationRecord.Contract__r.CurrencyIsoCode;
                installationRecord.Subscription_Annual_Order_Value__c = installationRecord.Package__r.InstallationCost__c;
                Contract relatedContract = contractMap.get(installationRecord.Contract__c);
                if (installationRecord.Contract__r.SBQQ__Quote__r.SBQQ__Type__c != 'Renewal') {
                    if (installationRecord.Installation_Start_date__c == null && installationRecord.Installation_End_date__c == null) {
                        if (relatedContract != null) {
                            installationRecord.Installation_Start_date__c = relatedContract.StartDate;
                            installationRecord.Installation_End_date__c = relatedContract.EndDate;
                        }
                    }
                } else {
                    installationRecord.Installation_End_date__c = relatedContract.EndDate;
                }
            }

            if (!installationList.isEmpty()) {
                update installationList;
            }
        } catch (Exception ex) {
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
        }
    }

    private static Set<Id> pendingContractMetricsIds = new Set<Id>();
    private static Boolean contractMetricsJobQueued = false;

    public static void enqueueContractMetricsRecalc(Set<Id> contractIds) {
        if (contractIds == null || contractIds.isEmpty()) {
            return;
        }

        pendingContractMetricsIds.addAll(contractIds);

        if (System.isFuture() || System.isQueueable() || System.isBatch()) {
            runContractMetricsRecalc(new Set<Id>(pendingContractMetricsIds));
            pendingContractMetricsIds.clear();
            contractMetricsJobQueued = false;
            return;
        }

        if (contractMetricsJobQueued) {
            return;
        }

        recalcContractMetricsAsync(new Set<Id>(pendingContractMetricsIds));
        pendingContractMetricsIds.clear();
        contractMetricsJobQueued = true;
    }

    public static void recalcContractMetricsAsync(Set<Id> contractIds) {
        if (contractIds == null || contractIds.isEmpty()) {
            return;
        }
        System.enqueueJob(new ContractMetricsRecalcQueueable(contractIds));
    }

    public class ContractMetricsRecalcQueueable implements Queueable {
        private final Set<Id> contractIds;

        public ContractMetricsRecalcQueueable(Set<Id> ids) {
            this.contractIds = (ids == null) ? new Set<Id>() : new Set<Id>(ids);
        }

        public void execute(QueueableContext context) {
            if (contractIds == null || contractIds.isEmpty()) {
                return;
            }
            runContractMetricsRecalc(contractIds);
            contractMetricsJobQueued = false;
        }
    }

    private static void runContractMetricsRecalc(Set<Id> contractIds) {
        if (contractIds == null || contractIds.isEmpty()) {
            return;
        }
        Boolean previousSuppression = suppressMetricsRecalc;
        suppressMetricsRecalc = true;
        try {
            recalcContractMetrics(contractIds);
        } finally {
            suppressMetricsRecalc = previousSuppression;
        }
    }

    private static void recalcContractMetrics(Set<Id> contractIds) {
        if (contractIds == null || contractIds.isEmpty()) {
            return;
        }

        Map<Id, Contract> contractsToProcess = new Map<Id, Contract>([
            SELECT Id, Status, Subscription_Value__c, No_of_Installations__c
            FROM Contract
            WHERE Id IN :contractIds
        ]);

        updateContractMetricsFromPackages(contractsToProcess);
    }

    @TestVisible
    private static void updateContractMetricsFromPackages(Map<Id, Contract> updatedContracts) {
        if (updatedContracts == null || updatedContracts.isEmpty()) {
            return;
        }

        Set<Id> eligibleContractIds = new Set<Id>();
        for (Contract contractRecord : updatedContracts.values()) {
            if (contractRecord == null || contractRecord.Id == null) {
                continue;
            }
            if (contractRecord.Status != null && contractRecord.Status.equalsIgnoreCase('Terminated')) {
                continue;
            }
            eligibleContractIds.add(contractRecord.Id);
        }

        if (eligibleContractIds.isEmpty()) {
            return;
        }

        List<Package__c> contractPackages = [
            SELECT Id, Contract__c, InstallationCost__c, Installation_Cost__c, Installation_Quantity__c
            FROM Package__c
            WHERE Contract__c IN :eligibleContractIds
        ];

        if (contractPackages.isEmpty()) {
            return;
        }

        Map<Id, Decimal> subscriptionTotals = new Map<Id, Decimal>();
        Map<Id, Decimal> installationTotals = new Map<Id, Decimal>();

        // Roll up manually so currency math uses each package record currency (multi-currency safe)
        for (Package__c pkg : contractPackages) {
            if (pkg == null || pkg.Contract__c == null) {
                continue;
            }

            Decimal quantity = pkg.Installation_Quantity__c == null ? 0 : pkg.Installation_Quantity__c;
            Decimal unitCost = pkg.InstallationCost__c != null ? pkg.InstallationCost__c : pkg.Installation_Cost__c;
            Decimal packageValue = (unitCost == null || quantity == null) ? 0 : unitCost * quantity;

            if (!subscriptionTotals.containsKey(pkg.Contract__c)) {
                subscriptionTotals.put(pkg.Contract__c, 0);
            }
            if (!installationTotals.containsKey(pkg.Contract__c)) {
                installationTotals.put(pkg.Contract__c, 0);
            }

            subscriptionTotals.put(pkg.Contract__c, subscriptionTotals.get(pkg.Contract__c) + packageValue);
            installationTotals.put(pkg.Contract__c, installationTotals.get(pkg.Contract__c) + quantity);
        }

        List<Contract> contractsToUpdate = new List<Contract>();

        for (Id contractId : eligibleContractIds) {
            Boolean hasPackages = subscriptionTotals.containsKey(contractId) || installationTotals.containsKey(contractId);
            if (!hasPackages) {
                continue;
            }

            Contract source = updatedContracts.get(contractId);
            Contract updateRecord = new Contract(Id = contractId);
            Boolean needsUpdate = false;

            if (subscriptionTotals.containsKey(contractId)) {
                Decimal newSubscriptionTotal = subscriptionTotals.get(contractId).setScale(2);
                Decimal currentSubscription = source.Subscription_Value__c;

                if (currentSubscription == null || currentSubscription.setScale(2) != newSubscriptionTotal) {
                    updateRecord.Subscription_Value__c = newSubscriptionTotal;
                    needsUpdate = true;
                }
            }

            if (installationTotals.containsKey(contractId)) {
                Decimal newInstallationTotal = installationTotals.get(contractId).setScale(0);
                Decimal currentInstallations = source.No_of_Installations__c;

                if (currentInstallations == null || currentInstallations.setScale(0) != newInstallationTotal) {
                    updateRecord.No_of_Installations__c = newInstallationTotal;
                    needsUpdate = true;
                }
            }

            if (needsUpdate) {
                contractsToUpdate.add(updateRecord);
            }
        }

        if (!contractsToUpdate.isEmpty()) {
            update contractsToUpdate;
        }
    }

    private static void activateInstallations(List<Installation__c> instList) {
     
        List<Installation__c> renewalInsts = new List<Installation__c>();
    
        for (Installation__c inst : instList) {
            inst.Installation_End_date__c = inst.Contract__r.EndDate;
            inst.Quote__c = inst.Order__r?.SBQQ__Quote__c;
            
            if (inst.Contract__r.SBQQ__Quote__r.SBQQ__Type__c == 'Renewal') {
                renewalInsts.add(inst);
            }
        }
    
        if (!instList.isEmpty()) {
            update instList;
        }
    
        if (!renewalInsts.isEmpty()) {
            Set<Id> renewalInstIds = new Set<Id>();
            for (Installation__c inst : renewalInsts) {
                if (inst != null && inst.Id != null) {
                    renewalInstIds.add(inst.Id);
                }
            }
            if (!renewalInstIds.isEmpty()) {
                Database.executeBatch(new InstallationsRenewalBatch(renewalInstIds), 50);
            }
        } 
    }

}