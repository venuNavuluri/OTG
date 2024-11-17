/*
*   
*   bg_ClearDuplicateBypass
*   Author  : BrightGen Limited
*   Created : ?
*
*   Class   : bg_ClearDuplicateBypass
*           
*   Changes : 29/11/2023 ADS - Case 65144 - Handle Apex Collections when an Account appears more than once in the List

*   Changes : 23/09/2024 For Duplicate Account Id in List By Akash Dhole
*/

public class bg_ClearDuplicateBypass
{
    @InvocableMethod
    public static void ClearDuplicateBypass(List<List<Account>> accs)
    {
        if(accs != NULL && !accs.isEmpty())
        {
            List<Account> accsToUpdate = new List<Account>();
            Set<Id> uniqueAccountIds = new Set<Id>(); // To store unique account IDs
            
            for (List<Account> accounts : accs)
            {
                if(accounts != NULL && !accounts.isEmpty())
                {
                    for (Account acc : accounts)
                    {
                        // Check if the account ID is already in the set (i.e., duplicate)
                        if (acc.Id != null && !uniqueAccountIds.contains(acc.Id))
                        {
                            acc.Bypass_Duplicate_Rule__c = false;
                            accsToUpdate.add(acc);
                            uniqueAccountIds.add(acc.Id); // Add to set to track uniqueness
                        }
                    }
                }
            }
            
            if (!accsToUpdate.isEmpty())
            {
                Database.DMLOptions dml = new Database.DMLOptions();
                dml.DuplicateRuleHeader.allowSave = true;
                dml.DuplicateRuleHeader.runAsCurrentUser = true;
                Database.update(accsToUpdate, dml);
            }
        }
    }
}