trigger bg_User_au on User (after update) {

    VRConfiguration__c bypassTrig = VRConfiguration__c.getInstance();
    if (bypassTrig != null && bypassTrig.ByPass_User_Triggers__c) {
        System.debug('bg_User_au Trigger skipped for user: ');
        return;
    }   

    List<Id> salesOfficeUserIdsToProcess = new List<Id>();
    for (User u : Trigger.new)
    {
        if (u.Sales_Office__c != Trigger.oldMap.get(u.Id).Sales_Office__c)
        {
            salesOfficeUserIdsToProcess.add(u.Id);
        }
    }
    if (!salesOfficeUserIdsToProcess.isEmpty())
    {
        bg_UserUtils.UpdateAccountVismaModified(salesOfficeUserIdsToProcess);
    }
    

}