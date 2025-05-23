public class ActivateOrderController
{
    @AuraEnabled
    public static string activateOrder(String ordId, Date activatedDate)
    {
        System.debug('ordId --> ' + ordId);
        try
        {
            activatedDate = activatedDate == NULL ? Date.today() : activatedDate;
            Order ord = new Order(
                Id = ordId,
                Status = 'Activated',
                SBQQ__Contracted__c = TRUE,
                Is_Activated__c = TRUE,
                //EffectiveDate = activatedDate,
                ActivatedDate = activatedDate
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