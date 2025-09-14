public without sharing class UpdateContractAmended {

    public static void updateAmendContract(List<Opportunity> newOppList, Map<Id, Opportunity> oldOppMap) {
        Set<Id> contractIds = new Set<Id>();

        // Step 1: Identify contracts that were updated
        for (Opportunity opp : newOppList) {
            Boolean contractChanged = false;

            if ((oldOppMap != null && oldOppMap.containsKey(opp.Id)) &&
                opp.Amend_Contract_Sales__c != null &&
                opp.Amend_Contract_Sales__c != oldOppMap.get(opp.Id).Amend_Contract_Sales__c) {
                contractChanged = true;
            } else if ((oldOppMap == null || !oldOppMap.containsKey(opp.Id)) &&
                       opp.Amend_Contract_Sales__c != null) {
                contractChanged = true;
            }

            if (contractChanged) {
                contractIds.add(opp.Amend_Contract_Sales__c);
            }
        }

        // Step 2: Query related Contracts
        Map<Id, Contract> contractMap = new Map<Id, Contract>(
            [SELECT Id, Subscription_Value__c, CurrencyIsoCode FROM Contract WHERE Id IN :contractIds]
        );

        // Step 3: Apply updates
        for (Opportunity opp : newOppList) {
            if (opp.Amend_Contract_Sales__c != null && contractMap.containsKey(opp.Amend_Contract_Sales__c)) {
                Contract relatedContract = contractMap.get(opp.Amend_Contract_Sales__c);
                opp.SBQQ__AmendedContract__c = relatedContract.Id;
                opp.Account_Subscription_Annual_Order_Value__c = relatedContract.Subscription_Value__c;
                opp.CurrencyIsoCode = relatedContract.CurrencyIsoCode;
            }
        }
    }
}