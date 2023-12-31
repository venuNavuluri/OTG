trigger bg_Account_au on Account (after update)
{
    List<Account> replicasToRecalculate = new List<Account>();
    List<Account> ultimateParentAccountChanges = new List<Account>();

    for (Account acc : Trigger.new)
    {
        Account oldAcc = Trigger.oldMap.get(acc.Id);
        if (acc.B2B_Account__c != null && oldAcc != null && acc.RecordTypeId != oldAcc.RecordTypeId)
        {
            replicasToRecalculate.add(acc);
        }

        Boolean hierarchyFieldChanged = acc.Ultimate_Parent_Email__c != oldAcc.Ultimate_Parent_Email__c || 
                                        acc.Ultimate_Parent_Owner__c != oldAcc.Ultimate_Parent_Owner__c ||
                                        acc.Ultimate_Parent_Id__c != oldAcc.Ultimate_Parent_Id__c ||
                                        acc.Ultimate_Parent_Name__c != oldAcc.Ultimate_Parent_Name__c ||
                                        acc.Ultimate_Parent_Owner_Id__c != oldAcc.Ultimate_Parent_Owner_Id__c;
        if (hierarchyFieldChanged && acc.RecordTypeId == bg_AccountUtils.b2bRTId)
        {
            ultimateParentAccountChanges.add(acc);
        }
    }

    if (!replicasToRecalculate.isEmpty())
    {
        bg_AccountUtils.RecalculateReplicas(replicasToRecalculate);
    }

    if (!ultimateParentAccountChanges.isEmpty())
    {
        bg_AccountUtils.PopulateHierarchyFieldsFromUltimateParent(ultimateParentAccountChanges);
    }
}