public with sharing class FutureInstallationTerminationScheduler implements Schedulable {
    public void execute(SchedulableContext context) {
        Database.executeBatch(new FutureInstallationTerminationBatch(), 1);
    }
}
