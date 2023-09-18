trigger bg_Account_ai on Account (after insert)
{
    List<Account> replicasToRecalculate = new List<Account>();
    for (Account acc : Trigger.new)
    {
        if (acc.B2B_Account__c != null)
        {
            replicasToRecalculate.add(acc);
        }
    }

    if (!replicasToRecalculate.isEmpty())
    {
        bg_AccountUtils.RecalculateReplicas(replicasToRecalculate);
    }

    bg_AccountUtils.PopulateUltimateParentIdField(Trigger.new);
    
}