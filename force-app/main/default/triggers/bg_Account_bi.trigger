trigger bg_Account_bi on Account (before insert)
{
    String b2bRTId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('B2B Account').getRecordTypeId();
    String replicaRTId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Replica Invoice Account').getRecordTypeId();

    List<Account> accEmailFields = new List<Account>();
    List<Account> replicaInvoiceAccounts = new List<Account>();
    List<Account> b2bAccounts = new List<Account>();

    for (Account acc : Trigger.new)
    {
        for (String fieldName : bg_AccountUtils.ACC_EMAIL_FIELDS)
        {
            String fieldValue = (String) acc.get(fieldName);
            if (fieldValue != null)
            {
                accEmailFields.add(acc);
                break;
            }
        }
        

        if (acc.RecordTypeId == replicaRTId && acc.B2B_Account__c != null)
        {
            replicaInvoiceAccounts.add(acc);
        }

        if (acc.RecordTypeId == b2bRTId)
        {
            b2bAccounts.add(acc);
        }
    }

    if (!b2bAccounts.isEmpty())
    {
        bg_AccountUtils.AssignSalesPersonOwner(b2bAccounts);
    }

    if (!accEmailFields.isEmpty())
    {
        bg_AccountUtils.ValidateAccEmailFields(accEmailFields);
    }

    if (!replicaInvoiceAccounts.isEmpty())
    {
        bg_AccountUtils.BlockMultipleReplicaAccounts(replicaInvoiceAccounts);
    }

    bg_AccountUtils.PopulateHierarchyFields(Trigger.new);

}