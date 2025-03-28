public with sharing class ActivateInstallationController {
    
    @AuraEnabled
    public static String activateInstallation(String recId, Date startDate) {
        SavePoint sp = Database.setSavePoint();
        try {
            Logger.info('Activating installation for Id: ' + recId + ' with startDate: ' + startDate);
            Logger.saveLog();

            updateInstallationStartDate(recId, startDate);

            Installation__c inst = [
                SELECT Id, Name, Contract__c, Quote_Line_Group__c, Package__c
                FROM Installation__c
                WHERE Id = :recId
                LIMIT 1
            ];

            deleteExistingInstallationLinesAndSalesOrders(inst.Id);

            List<SBQQ__Subscription__c> subscriptions = fetchSubscriptionsFromOrderItems(inst.Quote_Line_Group__c, inst.Package__c);

            if (!subscriptions.isEmpty()) {
                createInstallationLines(inst, subscriptions, startDate);
            }

            inst.Installation_Order_Status__c = 'Active';
            update inst;

            CreateSalesOrderService.createSORecords(new List<Installation__c>{inst});

            Logger.info('Installation activation and SO creation completed for Id: ' + recId);
            Logger.saveLog();
            return 'SUCCESS';

        } catch (Exception ex) {
            Database.rollback(sp);
            Logger.error('Error in activateInstallation: ' + ex.getMessage() + '\n' + ex.getStackTraceString());
            Logger.saveLog();
            throw new AuraHandledException('Installation activation failed: ' + ex.getMessage());
        }
    }

    private static void updateInstallationStartDate(Id instId, Date startDate) {
        update new Installation__c(Id = instId, Installation_Start_Date__c = startDate);
    }

    private static void deleteExistingInstallationLinesAndSalesOrders(Id installationId) {
        try {
            List<Sales_Order__c> relatedSOs = [SELECT Id FROM Sales_Order__c WHERE Installation__c = :installationId];
            if (!relatedSOs.isEmpty()) {
                delete relatedSOs;
                Logger.info('Deleted ' + relatedSOs.size() + ' Sales Orders for Installation: ' + installationId);
                Logger.saveLog();
            }

            List<Installation_Line__c> existingLines = [SELECT Id FROM Installation_Line__c WHERE Installation__c = :installationId];
            if (!existingLines.isEmpty()) {
                delete existingLines;
                Logger.info('Deleted ' + existingLines.size() + ' Installation Lines for Installation: ' + installationId);
                Logger.saveLog();
            }
        } catch (Exception ex) {
            Logger.error('Error while deleting Installation Lines or Sales Orders: ' + ex.getMessage());
            Logger.saveLog();
            throw ex;
        }
    }

    private static List<SBQQ__Subscription__c> fetchSubscriptionsFromOrderItems(Id quoteLineGroupId, Id packageId) {
        Logger.info('Fetching Subscriptions using Order Items for Quote Line Group: ' + quoteLineGroupId + ' and Package: ' + packageId);
        Logger.saveLog();

        List<OrderItem> orderItems = [
            SELECT Id
            FROM OrderItem
            WHERE Quote_Line_Group__c = :quoteLineGroupId
            AND Package__c = :packageId
        ];

        if (orderItems.isEmpty()) {
            Logger.warn('No Order Items found matching the provided Quote Line Group and Package.');
            Logger.saveLog();
            return new List<SBQQ__Subscription__c>();
        }

        Set<Id> orderItemIds = new Set<Id>();
        for (OrderItem oi : orderItems) {
            orderItemIds.add(oi.Id);
        }

        List<SBQQ__Subscription__c> subscriptions = [
            SELECT Id, Name, SBQQ__Product__c, SBQQ__Product__r.Name, SBQQ__NetPrice__c,
                   SBQQ__SegmentStartDate__c, SBQQ__SegmentEndDate__c, CurrencyIsoCode,
                   SBQQ__OrderProduct__c, SBQQ__QuoteLine__c
            FROM SBQQ__Subscription__c
            WHERE SBQQ__OrderProduct__c IN :orderItemIds
        ];

        Logger.info('Fetched ' + subscriptions.size() + ' Subscriptions from Order Items.');
        Logger.saveLog();

        return subscriptions;
    }

    private static void createInstallationLines(Installation__c inst, List<SBQQ__Subscription__c> subscriptions, Date startDate) {
        List<Installation_Line__c> instLines = new List<Installation_Line__c>();

        for (SBQQ__Subscription__c sub : subscriptions) {
            instLines.add(new Installation_Line__c(
                Name = sub.SBQQ__Product__r.Name,
                Installation__c = inst.Id,
                Subscription__c = sub.Id,
                Quote_Line__c = sub.SBQQ__QuoteLine__c,
                Product__c = sub.SBQQ__Product__c,
                Start_Date__c = sub.SBQQ__SegmentStartDate__c,
                End_Date__c = sub.SBQQ__SegmentEndDate__c,
                Net_Total__c = sub.SBQQ__NetPrice__c,
                CurrencyIsoCode = sub.CurrencyIsoCode
            ));
        }

        if (!instLines.isEmpty()) {
            insert instLines;
            Logger.info('Inserted ' + instLines.size() + ' Installation Lines for Installation: ' + inst.Id);
            Logger.saveLog();
        }
    }

    private static Decimal calculateProratedAmount(Decimal netPrice, Date segmentStart, Date segmentEnd, Date instStart) {
        Integer totalSegmentDays = segmentStart.daysBetween(segmentEnd) + 1;
        Integer remainingDays = instStart.daysBetween(segmentEnd) + 1;
        if (totalSegmentDays <= 0 || remainingDays <= 0) return 0;
        return (netPrice / totalSegmentDays * remainingDays).setScale(2);
    }
}