public class CreateInstallationLineScheduler implements Schedulable
{
    public Id ordId;
    public void execute(SchedulableContext SC)
    {
        try
        {
            List<Order> ordList = [SELECT Id, Name, SBQQ__Quote__c, SBQQ__Quote__r.Installation__c FROM Order WHERE Id = :ordId]; //AND SBQQ__Quote__r.Installation__c != NULL];
            if(ordList != NULL && !ordList.isEmpty())
            {
                List<Installation__c> instList = [SELECT Id, Name,Installation_Order_Status__c FROM Installation__c WHERE Quote__c = :ordList[0].SBQQ__Quote__c AND Installation_Order_Status__c = 'Draft'];
                List<Id> instIdList = new List<Id>();
                for(Installation__c inst : instList)
                {
                    inst.Installation_Order_Status__c = 'Active';
                    instIdList.add(inst.Id);
                }
                CreateInstallationsController.goToInstallationLineCreation(instIdList);
                update instList;
            }
        }
        catch(Exception ex)
        {
            System.debug('ex --> ' + ex);
            System.debug('ex line --> ' + ex.getLineNumber());
            System.debug('ex stack --> ' + ex.getStackTraceString());
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
        }
    }
}