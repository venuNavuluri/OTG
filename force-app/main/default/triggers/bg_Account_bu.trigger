trigger bg_Account_bu on Account (before update)
{
    String replicaRTId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Replica Invoice Account').getRecordTypeId();

    List<Account> accEmailFields = new List<Account>();
    List<Account> replicaInvoiceAccounts = new List<Account>();
    List<Account> replicaToInvoiceRTAccounts = new List<Account>();
    List<Account> hierarchyUpdates = new List<Account>();

    for (Account acc : Trigger.new)
    {
        System.debug(LoggingLevel.ERROR, acc.Ultimate_Parent_Email__c);
        Account oldAccount = Trigger.oldMap.get(acc.Id);
        Boolean hierarchyFieldIsNull = acc.Ultimate_Parent_Email__c == null || 
                                       acc.Ultimate_Parent_Owner__c == null || 
                                       acc.Ultimate_Parent_Owner_Id__c == null ||
                                       acc.Ultimate_Parent_Id__c == null ||
                                       acc.Ultimate_Parent_Name__c == null;
        Boolean ownerChanged = acc.OwnerId != oldAccount.OwnerId;
        Boolean parentChanged = acc.ParentId != oldAccount.ParentId;
        Boolean nameChanged = acc.Name != oldAccount.Name;

        if (hierarchyFieldIsNull || ownerChanged || parentChanged || nameChanged)
        {
            hierarchyUpdates.add(acc);
        }

        for (String fieldName : bg_AccountUtils.ACC_EMAIL_FIELDS)
        {
            String fieldValue = (String) acc.get(fieldName);
            String oldFieldValue = (String) oldAccount.get(fieldName);
            if (fieldValue != null && fieldValue != oldFieldValue)
            {
                accEmailFields.add(acc);
                break;
            }
        }

        if (acc.RecordTypeId == replicaRTId && acc.B2B_Account__c != null)
        {
            replicaInvoiceAccounts.add(acc);
        }

        if (acc.RecordTypeId != replicaRTId && oldAccount.RecordTypeId == replicaRTId)
        {
            replicaToInvoiceRTAccounts.add(acc);
        }

    }

    if (!accEmailFields.isEmpty())
    {
        bg_AccountUtils.ValidateAccEmailFields(accEmailFields);
    }

    if (!replicaInvoiceAccounts.isEmpty())
    {
        bg_AccountUtils.BlockMultipleReplicaAccounts(replicaInvoiceAccounts);
    }

    if (!replicaToInvoiceRTAccounts.isEmpty())
    {
        bg_AccountUtils.BlockReplicaToInvoiceRTChange(replicaToInvoiceRTAccounts);
    }

    if (!hierarchyUpdates.isEmpty())
    {
        bg_AccountUtils.PopulateHierarchyFields(hierarchyUpdates);
    }
}