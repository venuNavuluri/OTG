public class CreateInstallationLineScheduler implements Schedulable
{
    public Id ordId;
    public void execute(SchedulableContext SC)
    {
        try
        {
            List<Order> ordList = [SELECT Id, Name, SBQQ__Quote__c, SBQQ__Quote__r.Installation__c FROM Order WHERE Id = :ordId AND SBQQ__Quote__r.Installation__c != NULL];
            if(ordList != NULL && !ordList.isEmpty())
            {
                Installation__c inst = new Installation__c(
                    Id = ordList[0].SBQQ__Quote__r.Installation__c,
                    Installation_Order_Status__c = 'Active'
                );
                CreateInstallationsController.goToInstallationLineCreation(new List<Id>{inst.Id});
                update inst;
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