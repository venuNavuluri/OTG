trigger bg_Account_au on Account (after update)
{
    VRConfiguration__c bypassTrig = VRConfiguration__c.getInstance();
    if (bypassTrig != null && bypassTrig.ByPass_Account_Triggers__c) {
        System.debug('bg_Account_au Trigger skipped for user: ');
        return;
    }

    List<Account> replicasToRecalculate = new List<Account>();
    List<Account> ultimateParentAccountChanges = new List<Account>();
    
    List<Account> paymentTermsChangedAccounts = new List<Account>();

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
                                        acc.Ultimate_Parent_Owner_Id__c != oldAcc.Ultimate_Parent_Owner_Id__c ||
            							acc.Ultimate_Parent_Account_Segmentation__c != oldAcc.Ultimate_Parent_Account_Segmentation__c ||
            							acc.Ultimate_Parent_Account_Number__c != oldAcc.Ultimate_Parent_Account_Number__c ||
            							acc.Ultimate_Parent_Account_Sub_AOV__c != oldAcc.Ultimate_Parent_Account_Sub_AOV__c;
        								
        if (hierarchyFieldChanged && acc.RecordTypeId == bg_AccountUtils.b2bRTId)
        {
            ultimateParentAccountChanges.add(acc);
        }
        
        if (acc.Customer_Payment_Terms__c != oldAcc.Customer_Payment_Terms__c) {
            paymentTermsChangedAccounts.add(acc);
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
    
    if (!paymentTermsChangedAccounts.isEmpty()) {
        bg_AccountUtils.updateNonApprovedQuotesForAccounts(paymentTermsChangedAccounts);
    }
}