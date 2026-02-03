public with sharing class OpportunityTriggerHandler {
    // Re-entrancy guard
    private static Boolean isExecuting = false;

    // Entry points per context
    public static void beforeInsert(List<Opportunity> newList) {
        if (start()) {
            try {
                // Add your before insert logic here
                // Example: defaulting fields or validation
                // validateCloseDate(newList);
                manageCreatedBySalesUser(newList);
            } finally { stop(); }
        }
    }

    public static void beforeUpdate(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        if (start()) {
            try {
                // Add your before update logic here
                // Example: prevent stage regression, normalize data
                // normalizeFields(newList);
            } finally { stop(); }
        }
    }

    public static void beforeDelete(List<Opportunity> oldList) {
        if (start()) {
            try {
                // Add your before delete logic here
            } finally { stop(); }
        }
    }

    public static void afterInsert(List<Opportunity> newList) {
        if (start()) {
            try {
                // Add your after insert logic here
                // Example: enqueue async jobs, create related records
            } finally { stop(); }
        }
    }

    public static void afterUpdate(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        if (start()) {
            try {
                // Update Account_Subscription_Annual_Order_Value__c on related Account
                // when SBQQ__AmendedContract__c changes and the amended contract Name is the target value.
                updateOpportunityAnnualValueFromContract(newList, oldMap);
                // Keep placeholder for other after update logic
                // handleStageChanges(newList, oldMap);
            } finally { stop(); }
        }
    }

    public static void afterDelete(List<Opportunity> oldList) {
        if (start()) {
            try {
                // Add your after delete logic here
            } finally { stop(); }
        }
    }

    public static void afterUndelete(List<Opportunity> newList) {
        if (start()) {
            try {
                // Add your after undelete logic here
            } finally { stop(); }
        }
    }

    // Common guard helpers
    private static Boolean start() {
        if (isExecuting) return false;
        isExecuting = true;
        return true;
    }
    private static void stop() {
        isExecuting = false;
    }

    // ===== Main implementation for updating Opportunity annual value from amended contract =====
    @TestVisible
    private static void updateOpportunityAnnualValueFromContract(List<Opportunity> newOpportunities, Map<Id, Opportunity> oldOpportunityMap) {
        if (newOpportunities == null || newOpportunities.isEmpty()) {
            return;
        }

        Map<Id, Opportunity> newOpportunityMap = new Map<Id, Opportunity>(newOpportunities);
        Map<Id, Opportunity> oldOpportunityMapSafe = (oldOpportunityMap == null)
            ? new Map<Id, Opportunity>()
            : oldOpportunityMap;

        Set<Id> targetContractIds = new Set<Id>();
        Map<Id, Id> oppIdToContractId = new Map<Id, Id>();

        for (Opportunity newOpp : newOpportunities) {
            Opportunity oldOpp = oldOpportunityMapSafe.get(newOpp.Id);

            if (newOpp.Business_Unit__c != 'HCM Learning, Assessment and Competency') {
                continue;
            }

            if (!String.isBlank(newOpp.StageName) && newOpp.StageName.equalsIgnoreCase('Closed Won')) {
                continue;
            }

            Id targetContractId = newOpp.SBQQ__AmendedContract__c;

            if (targetContractId == null && 'Renewal'.equalsIgnoreCase(newOpp.Existing_Opportunity_Type__c)) {
                targetContractId = newOpp.SBQQ__RenewedContract__c;
            }

            if (targetContractId == null) {
                continue;
            }

            targetContractIds.add(targetContractId);
            oppIdToContractId.put(newOpp.Id, targetContractId);
        }

        if (targetContractIds.isEmpty()) {
            return;
        }

        Map<Id, Contract> contractsById = new Map<Id, Contract>([
            SELECT Id, Subscription_Value__c
            FROM Contract
            WHERE Id IN :targetContractIds
        ]);

        if (contractsById.isEmpty()) {
            return;
        }

        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
        for (Id oppId : oppIdToContractId.keySet()) {
            Opportunity newOpp = newOpportunityMap.get(oppId);
            Id contractId = oppIdToContractId.get(oppId);

            if (!contractsById.containsKey(contractId)) {
                continue;
            }

            Contract relatedContract = contractsById.get(contractId);

            if (relatedContract == null) {
                continue;
            }

            Decimal newContractValue = relatedContract.Subscription_Value__c;

            if (newContractValue == null) {
                continue;
            }

            Decimal currentValue = newOpp.Account_Subscription_Annual_Order_Value__c;

            if (currentValue == newContractValue) {
                continue;
            }

            Opportunity recordToUpdate = new Opportunity(
                Id = oppId,
                Account_Subscription_Annual_Order_Value__c = newContractValue
            );
            opportunitiesToUpdate.add(recordToUpdate);
        }

        if (!opportunitiesToUpdate.isEmpty()) {
            update opportunitiesToUpdate;
        }
    }
    private static void manageCreatedBySalesUser(List<Opportunity> newOpportunities)
    {
        Id userRoleId = UserInfo.getUserRoleId();
        
        if (userRoleId != null)
        {
            UserRole r = [select Id, Name from UserRole where Id = :userRoleId];
            
            for (Opportunity opp : newOpportunities)
            {
                if (r.Name.contains('Sales') && r.Name != 'Sales Ops' && r.Name != 'Non Sales')
                {
                    opp.Created_By_Sales_User__c = 'Yes';
                }
            }
        }
    }
}