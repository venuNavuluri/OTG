public with sharing class InstallationsChangePackageService {

    /**
     * Orchestrates the change package processing for installations
     * @param installations List of installations to process
     * @param activationDate Date to use for activation/termination
     */
    public static void process(List<Installation__c> installations, Date activationDate) {
        if (installations == null || installations.isEmpty()) {
            return;
        }

        // Step 1: Terminate existing sales orders
        terminateExistingSalesOrders(installations, activationDate);

        // Step 2: End existing installation lines
        endExistingInstallationLines(installations, activationDate);

        // Step 3: Fetch subscriptions for installations
        Map<Id, List<SBQQ__Subscription__c>> subscriptionsByInstallation =
            InstallationsRenewalService.fetchSubscriptionsByInstallations(installations);

        // Step 4: Create new installation lines
        List<Installation__c> installationsForSalesOrderGeneration = createNewInstallationLines(
            installations, 
            subscriptionsByInstallation, 
            activationDate
        );

        // Step 5: Generate sales orders for installations that have new lines
        if (!installationsForSalesOrderGeneration.isEmpty()) {
            SalesOrderGeneratorService.generateSalesOrders(
                installationsForSalesOrderGeneration, 
                false, 
                true
            );
        }
    }

    /**
     * Terminates existing sales orders for the given installations
     * @param installations List of installations to process
     * @param activationDate Date to use for termination
     */
    public static void terminateExistingSalesOrders(List<Installation__c> installations, Date activationDate) {
        for (Installation__c installation : installations) {
            InstallationTriggerHandler.handleTerminatedInstallations(
                new List<Id>{ installation.Id }, 
                activationDate
            );
        }
    }

    /**
     * Ends existing installation lines that are active or will become active
     * @param installations List of installations to process
     * @param activationDate Date to use for ending lines
     */
    public static void endExistingInstallationLines(List<Installation__c> installations, Date activationDate) {
        Set<Id> installationIds = new Set<Id>();
        for (Installation__c installation : installations) {
            installationIds.add(installation.Id);
        }
        
        if (installationIds.isEmpty()) {
            return;
        }

        List<Installation_Line__c> installationLinesToEnd = [
            SELECT Id 
            FROM Installation_Line__c
            WHERE Installation__c IN :installationIds 
            AND End_Date__c >= :Date.today()
        ];

        List<Installation_Line__c> installationLinesToUpdate = new List<Installation_Line__c>();
        for (Installation_Line__c installationLine : installationLinesToEnd) {
            installationLinesToUpdate.add(
                new Installation_Line__c(
                    Id = installationLine.Id, 
                    End_Date__c = activationDate
                )
            );
            // If you want no overlap use activationDate.addDays(-1)
        }
        
        if (!installationLinesToUpdate.isEmpty()) {
            update installationLinesToUpdate;
        }
    }

    /**
     * Creates new installation lines for installations with subscriptions
     * @param installations List of installations to process
     * @param subscriptionsByInstallation Map of subscriptions by installation ID
     * @param activationDate Date to use for activation
     * @return List of installations that have new lines created
     */
    public static List<Installation__c> createNewInstallationLines(
        List<Installation__c> installations,
        Map<Id, List<SBQQ__Subscription__c>> subscriptionsByInstallation,
        Date activationDate
    ) {
        List<Installation__c> installationsWithNewLines = new List<Installation__c>();

        for (Installation__c installation : installations) {
            List<SBQQ__Subscription__c> subscriptions = subscriptionsByInstallation.get(installation.Id);
            if (subscriptions == null || subscriptions.isEmpty()) {
                continue;
            }

            ActivateInstallationController.createInstallationLines(
                installation, 
                subscriptions, 
                activationDate
            );

            Integer newLinesCount = [
                SELECT COUNT() 
                FROM Installation_Line__c
                WHERE Installation__c = :installation.Id 
                AND Start_Date__c >= :activationDate
            ];
            
            if (newLinesCount > 0) {
                installationsWithNewLines.add(installation);
            }
        }
        
        return installationsWithNewLines;
    }
}