public class bg_UserUtils
{
    private static Set<String> salesPersonRoles;

    @future
    public static void UpdateAccountVismaModified(List<Id> userIds)
    {
        List<Account> accountsToUpdate = [SELECT Id FROM Account WHERE OwnerId IN :userIds];
        for (Account acct : accountsToUpdate)
        {
			acct.Visma_Modified_Date__c = Datetime.now();            
        }
        
        if (!accountsToUpdate.isEmpty())
        {
            update accountsToUpdate;
        }
    }

    public static void PopulateRoles()
    {
        if (salesPersonRoles == null)
        {
            salesPersonRoles = new Set<String>();
            
            List<Sales_Person_Role_Mapping__mdt> salesPersonRoleMappings = [SELECT Id, MasterLabel, DeveloperName FROM Sales_Person_Role_Mapping__mdt];
            for (Sales_Person_Role_Mapping__mdt mapping : salesPersonRoleMappings)
            {
                salesPersonRoles.add(mapping.MasterLabel);
                salesPersonRoles.add(mapping.DeveloperName);
            }
        }
    }

    public static Boolean IsSalesPerson(String roleName)
    {
        if (salesPersonRoles == null)
        {
            return null;
        }
        
        return salesPersonRoles.contains(roleName);
    }


    
}