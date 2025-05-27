public with sharing class InstallationsRenewalService {

    public static void processRenewalInstallations(List<Installation__c> installations) {
        List<SBQQ__Subscription__c> allSubs = fetchAllSubscriptions(installations);
        for (Installation__c inst : installations) {
            // Always use Contract Start Date as Installation Start Date for renewals
            Date installStartDate = inst.Contract__r.StartDate;

            List<SBQQ__Subscription__c> subsForInst = filterSubscriptionsByInstallation(inst, allSubs);
            ActivateInstallationController.createInstallationLines(inst, subsForInst, installStartDate);
        }

        SalesOrderGeneratorService.generateSalesOrders(installations, true); // Renewal flag passed
    }

    private static List<SBQQ__Subscription__c> fetchAllSubscriptions(List<Installation__c> installations) {
        Set<Id> orderIds = new Set<Id>();
        for (Installation__c inst : installations) {
            if (inst.Order__c != null) orderIds.add(inst.Order__c);
        }

        return [
            SELECT Id, SBQQ__OrderProduct__c, SBQQ__Product__c, SBQQ__Product__r.Name,
                   SBQQ__SegmentStartDate__c, SBQQ__SegmentEndDate__c, CurrencyIsoCode,
                   SBQQ__NetPrice__c, SBQQ__QuoteLine__c,
                   SBQQ__OrderProduct__r.OrderId
            FROM SBQQ__Subscription__c
            WHERE SBQQ__OrderProduct__r.OrderId IN :orderIds
        ];
    }

    private static List<SBQQ__Subscription__c> filterSubscriptionsByInstallation(Installation__c inst, List<SBQQ__Subscription__c> allSubs) {
        List<SBQQ__Subscription__c> result = new List<SBQQ__Subscription__c>();
        for (SBQQ__Subscription__c sub : allSubs) {
            if (sub.SBQQ__OrderProduct__r.OrderId == inst.Order__c) {
                result.add(sub);
            }
        }
        return result;
    }
}