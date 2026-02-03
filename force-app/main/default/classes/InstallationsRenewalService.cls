public with sharing class InstallationsRenewalService {

    public static void processRenewalInstallations(List<Installation__c> installations) {
        try {
            Map<Id, List<SBQQ__Subscription__c>> subsByInstallation = fetchSubscriptionsByInstallations(installations);
            List<Installation__c> validInstallationsForSO = new List<Installation__c>();
            List<Installation_Line__c> allLinesToInsert = new List<Installation_Line__c>();
            Set<Id> lineInstallations = new Set<Id>();

        for (Installation__c inst : installations) {
            Date installStartDate = inst.Contract__r.StartDate;
            List<SBQQ__Subscription__c> subsForInst = subsByInstallation.get(inst.Id);

            if (subsForInst != null && !subsForInst.isEmpty()) {
                List<Installation_Line__c> instLines = ActivateInstallationController.buildInstallationLines(inst, subsForInst, installStartDate);
                if (!instLines.isEmpty()) {
                    allLinesToInsert.addAll(instLines);
                    lineInstallations.add(inst.Id);
                }
            }
        }

            if (!allLinesToInsert.isEmpty()) {
                insert allLinesToInsert;
            }

            for (Installation__c inst : installations) {
                if (lineInstallations.contains(inst.Id)) {
                    validInstallationsForSO.add(inst);
                }
            }

            if (!validInstallationsForSO.isEmpty()) {
                SalesOrderGeneratorService.generateSalesOrders(validInstallationsForSO, true, false);
            }
        } finally {
        }
    }


    public static Map<Id, List<SBQQ__Subscription__c>> fetchSubscriptionsByInstallations(List<Installation__c> installations) {
        Map<Id, List<SBQQ__Subscription__c>> subsByInstId = new Map<Id, List<SBQQ__Subscription__c>>();
    
        Set<Id> quoteLineGroupIds = new Set<Id>();
        Set<Id> orderIds = new Set<Id>();
        Map<Id, Set<Id>> orderItemToInstallationIds = new Map<Id, Set<Id>>();
    
        for (Installation__c inst : installations) {
            if (inst.Quote_Line_Group__c != null) quoteLineGroupIds.add(inst.Quote_Line_Group__c);
            if (inst.Order__c != null) orderIds.add(inst.Order__c);
        }
    
        List<OrderItem> orderItems = [
            SELECT Id, Quote_Line_Group_ID__c, OrderId
            FROM OrderItem
            WHERE Quote_Line_Group_ID__c IN :quoteLineGroupIds
              AND OrderId IN :orderIds
        ];
    
        for (OrderItem oi : orderItems) {
            for (Installation__c inst : installations) {
                if (inst.Quote_Line_Group__c == oi.Quote_Line_Group_ID__c && inst.Order__c == oi.OrderId) {
                    if (!orderItemToInstallationIds.containsKey(oi.Id)) {
                        orderItemToInstallationIds.put(oi.Id, new Set<Id>());
                    }
                    orderItemToInstallationIds.get(oi.Id).add(inst.Id);
                }
            }
        }
    
        if (orderItemToInstallationIds.isEmpty()) {
            return subsByInstId;
        }
    
        List<SBQQ__Subscription__c> subs = [
            SELECT Id, Name, SBQQ__Product__c, SBQQ__Product__r.Name, SBQQ__NetPrice__c,SBQQ__StartDate__c, SBQQ__EndDate__c,
                   SBQQ__SegmentStartDate__c, SBQQ__SegmentEndDate__c, CurrencyIsoCode,
                   SBQQ__OrderProduct__c, SBQQ__QuoteLine__c
            FROM SBQQ__Subscription__c
            WHERE SBQQ__OrderProduct__c IN :orderItemToInstallationIds.keySet()
        ];
    
        for (SBQQ__Subscription__c sub : subs) {
            Set<Id> instIds = orderItemToInstallationIds.get(sub.SBQQ__OrderProduct__c);
            if (instIds != null) {
                for (Id instId : instIds) {
                    if (!subsByInstId.containsKey(instId)) {
                        subsByInstId.put(instId, new List<SBQQ__Subscription__c>());
                    }
                    subsByInstId.get(instId).add(sub);
                }
            }
        }
    
        return subsByInstId;
    }
}