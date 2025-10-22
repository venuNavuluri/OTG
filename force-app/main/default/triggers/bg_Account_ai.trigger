trigger bg_Account_ai on Account (after insert)
{
    VRConfiguration__c bypassTrig = VRConfiguration__c.getInstance();
    if (bypassTrig != null && bypassTrig.ByPass_Account_Triggers__c) {
        System.debug('bg_Account_ai Trigger skipped for user: ');
        return;
    }

    try{
        Id b2bRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('B2B Account').getRecordTypeId();
        List<Account> b2bAccounts = new List<Account>();
        
        List<Account> replicasToRecalculate = new List<Account>();
        for (Account acc : Trigger.new)
        {
            if (acc.B2B_Account__c != null)
            {
                replicasToRecalculate.add(acc);
            }
            if (acc.RecordTypeId == b2bRecordTypeId) {
                b2bAccounts.add(acc);
            }
            
        }
        
        if (!replicasToRecalculate.isEmpty())
        {
            bg_AccountUtils.RecalculateReplicas(replicasToRecalculate);
        }
        
        if (!b2bAccounts.isEmpty()){
            bg_AccountUtils.createProductSolutions(b2bAccounts);   
        }
        bg_AccountUtils.PopulateUltimateParentIdField(Trigger.new);
        
    }
    Catch(Exception ex){
        Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
        Logger.saveLog();
        
    }  
}