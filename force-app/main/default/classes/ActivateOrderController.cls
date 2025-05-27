public class ActivateOrderController
{
    @AuraEnabled
    public static string activateOrder(String ordId)
    {
        System.debug('ordId --> ' + ordId);
        try
        {
            Order ord = new Order(
                Id = ordId,
                Status = 'Activated',
                SBQQ__Contracted__c = TRUE
            );
            update ord;
            
            CreateInstallationLineScheduler cils = new CreateInstallationLineScheduler();
            cils.ordId = ord.Id;
            Time t = DateTime.now().addMinutes(2).time();
            Date dt = DateTime.now().addMinutes(2).date();
            String cronExp = '00 ' + t.minute() + ' ' + t.hour() + ' ' + dt.day() + ' ' + dt.month() + ' ? ' + dt.year();
            String jobId = System.schedule('Create Installation Lines ' + ord.Id, cronExp, cils);
            return 'SUCCESS';
        } catch (Exception ex) {
            System.debug('e --> ' + ex);
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            throw new AuraHandledException(ex.getMessage());
        }
    }
}