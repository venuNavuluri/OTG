public class CreateOrderScheduler implements Schedulable
{
    public String qtId;
    public void execute(SchedulableContext SC)
    {
        try
        {
            SBQQ__Quote__c qt = new SBQQ__Quote__c(
                Id = qtId,
                SBQQ__Status__c = 'Approved',
                SBQQ__Ordered__c = TRUE
            );
            update qt;
        }
        catch(Exception ex)
        {
            System.debug('ex --> ' + ex);
            System.debug('ex line --> ' + ex.getLineNumber());
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
        }
    }
}