public without sharing class UpdateContractAmended {

    public static void updateAmendContract(List<Opportunity> newOppList, Map<Id, Opportunity> oldOppMap) {
        OpportunityTriggerHandler.applyAmendedContractSelection(newOppList, oldOppMap);
    }
}
