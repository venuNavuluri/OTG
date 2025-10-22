public class QuoteLineTriggerHandler extends TriggerHandler {

    // Prevent re-running within the same transaction
    private static Boolean ranInTx = false;

    public override void beforeInsert() {
        if (ranInTx) return;
        ranInTx = true;
        updateQuoteLineGroupDetails((List<SBQQ__QuoteLine__c>) Trigger.new);
    }

    public override void afterInsert() {
        // no-op (left intentionally empty to avoid extra work)
    }

    /**
     * Sets SBQQ__Group__c on new Quote Lines, using Group_Name__c + Quote,
     * but only for Renewal/Amendment quotes.
     * Bulkified: 0-1 SOQL per trigger execution, no SOQL-in-loops.
     */
    public static void updateQuoteLineGroupDetails(List<SBQQ__QuoteLine__c> newQuoteLineList) {
        if (newQuoteLineList == null || newQuoteLineList.isEmpty()) return;

        // Collect only the rows that actually need mapping
        Set<Id>     neededQuoteIds   = new Set<Id>();
        Set<String> neededGroupNames = new Set<String>();
        for (SBQQ__QuoteLine__c ql : newQuoteLineList) {
            if (ql.SBQQ__Group__c == null
                && !String.isBlank(ql.Group_Name__c)
                && ql.SBQQ__Quote__c != null)
            {
                neededQuoteIds.add(ql.SBQQ__Quote__c);
                neededGroupNames.add(ql.Group_Name__c);
            }
        }
        if (neededQuoteIds.isEmpty() || neededGroupNames.isEmpty()) return;

        // Build a map: (QuoteId|GroupName) -> GroupId
        Map<String, Id> groupIdByQuoteAndName = new Map<String, Id>();

        // Single SOQL for exactly the groups we need, and only for Renewal/Amendment quotes
        for (SBQQ__QuoteLineGroup__c g : [
            SELECT Id, Name, SBQQ__Quote__c
            FROM SBQQ__QuoteLineGroup__c
            WHERE SBQQ__Quote__c IN :neededQuoteIds
              AND Name IN :neededGroupNames
              AND (SBQQ__Quote__r.SBQQ__Type__c = 'Renewal'
                   OR SBQQ__Quote__r.SBQQ__Type__c = 'Amendment')
        ]) {
            groupIdByQuoteAndName.put(g.SBQQ__Quote__c + '|' + g.Name, g.Id);
        }

        // Apply mapping
        for (SBQQ__QuoteLine__c ql : newQuoteLineList) {
            if (ql.SBQQ__Group__c == null
                && !String.isBlank(ql.Group_Name__c)
                && ql.SBQQ__Quote__c != null)
            {
                Id gid = groupIdByQuoteAndName.get(ql.SBQQ__Quote__c + '|' + ql.Group_Name__c);
                if (gid != null) {
                    ql.SBQQ__Group__c = gid;
                }
            }
        }
    }
}