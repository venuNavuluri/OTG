public with sharing class ActivateInstallationController {

    @AuraEnabled
    public static String activateInstallation(String recId, Date startDate) {
    SavePoint sp = Database.setSavePoint();
    try {
        Logger.info('Starting activateInstallation. Record ID: ' + recId + ', Start Date: ' + startDate);

        Installation__c inst = [
            SELECT Id, Name, Contract__c, Quote_Line_Group__c, Package__c, Order__c,
                Contract__r.StartDate, Contract__r.EndDate, Contract__r.Billing_Frequency__c, Contract__r.ContractTerm,
                Installation_End_Date__c, Installation_Start_Date__c, Invoice_Account__c, CurrencyIsoCode
            FROM Installation__c
            WHERE Id = :recId
            LIMIT 1
        ];

        Logger.info('Fetched Installation: ' + inst.Name + ', Contract Start: ' + inst.Contract__r.StartDate + ', End: ' + inst.Contract__r.EndDate);
        Logger.saveLog();
        
        inst.Installation_Start_Date__c = startDate;
        inst.Installation_End_Date__c = inst.Contract__r.EndDate;
        update inst;

        deleteExistingInstallationLinesAndSalesOrders(inst.Id);

        List<SBQQ__Subscription__c> subscriptions = fetchSubscriptionsFromOrderItems(inst.Quote_Line_Group__c, inst.Package__c, inst.Order__c);
        Logger.info('Fetched ' + subscriptions.size() + ' subscriptions from Order Items.');
        Logger.saveLog();

        if (!subscriptions.isEmpty()) {
            createInstallationLines(inst, subscriptions, startDate);
        } else {
            Logger.warn('No subscriptions found. Skipping Installation Line creation.');
            Logger.saveLog();
        }

        inst.Installation_Order_Status__c = 'Active';
        update inst;

        SalesOrderGeneratorService.generateSalesOrders(new List<Installation__c>{inst}, false, false);
        Logger.info('Sales Orders generated for Installation: ' + inst.Id);

        Logger.saveLog();
        return 'SUCCESS';

    } catch (Exception ex) {
        Database.rollback(sp);
        Logger.error('Error in activateInstallation: ' + ex.getMessage() + '\n' + ex.getStackTraceString());
        Logger.saveLog();
        throw new AuraHandledException('Installation activation failed: ' + ex.getMessage());
    }
}

    private static void deleteExistingInstallationLinesAndSalesOrders(Id installationId) {
        List<Sales_Order__c> relatedSOs = [SELECT Id FROM Sales_Order__c WHERE Installation__c = :installationId and Installation__r.DeleteInstallationLinesAndSOs__c = true];
        if (!relatedSOs.isEmpty()) delete relatedSOs;

        List<Installation_Line__c> existingLines = [SELECT Id FROM Installation_Line__c WHERE Installation__c = :installationId AND Installation__r.DeleteInstallationLinesAndSOs__c = true];
        if (!existingLines.isEmpty()) delete existingLines;
    }

    private static List<SBQQ__Subscription__c> fetchSubscriptionsFromOrderItems(Id quoteLineGroupId, Id packageId, Id orderId) {
        List<OrderItem> orderItems = [
            SELECT Id FROM OrderItem
            WHERE Quote_Line_Group_ID__c = :quoteLineGroupId AND OrderId = :orderId
        ];

        if (orderItems.isEmpty()) return new List<SBQQ__Subscription__c>();

        Set<Id> orderItemIds = new Set<Id>();
        for (OrderItem oi : orderItems) orderItemIds.add(oi.Id);

        return [
            SELECT Id, Name, SBQQ__Product__c, SBQQ__Product__r.Name, SBQQ__NetPrice__c,
                   SBQQ__SegmentStartDate__c, SBQQ__SegmentEndDate__c, CurrencyIsoCode,
                   SBQQ__OrderProduct__c, SBQQ__QuoteLine__c,SBQQ__StartDate__c,SBQQ__EndDate__c
            FROM SBQQ__Subscription__c
            WHERE SBQQ__OrderProduct__c IN :orderItemIds
        ];
    }

    public static void createInstallationLines(Installation__c inst, List<SBQQ__Subscription__c> subscriptions, Date installationStartDate) {
        Logger.info('--- START createInstallationLines for Installation: ' + inst.Id + ' ---');
        Logger.info('Installation Start Date: ' + installationStartDate + ', End Date: ' + inst.Installation_End_Date__c);
        Logger.info('Total subscriptions received: ' + subscriptions.size());
        Logger.saveLog();
    
        List<Installation_Line__c> instLines = new List<Installation_Line__c>();
        Date installationEndDate = inst.Installation_End_Date__c;
    
        // Group subscriptions by SBQQ__Product__c
        Map<Id, List<SBQQ__Subscription__c>> subsByProduct = new Map<Id, List<SBQQ__Subscription__c>>();
        for (SBQQ__Subscription__c sub : subscriptions) {
            if (!subsByProduct.containsKey(sub.SBQQ__Product__c)) {
                subsByProduct.put(sub.SBQQ__Product__c, new List<SBQQ__Subscription__c>());
            }
            subsByProduct.get(sub.SBQQ__Product__c).add(sub);
        }
        Logger.info('Grouped subscriptions by product. Product groups: ' + subsByProduct.keySet().size());
        Logger.saveLog();
    
        for (Id productId : subsByProduct.keySet()) {
            List<SBQQ__Subscription__c> productSubs = subsByProduct.get(productId);
    
            // Sort subscriptions by SBQQ__SegmentStartDate__c
            productSubs.sort(); // Assumes subscriptions are comparable (or sort logic is defined elsewhere)
    
            Boolean isFirst = true;
    
            for (SBQQ__Subscription__c sub : productSubs) {
                //Date subStart = sub.SBQQ__SegmentStartDate__c;
                //Date subEnd = sub.SBQQ__SegmentEndDate__c;
                Date subStart = (sub.SBQQ__SegmentStartDate__c != null) ? sub.SBQQ__SegmentStartDate__c : sub.SBQQ__StartDate__c;
                Date subEnd   = (sub.SBQQ__SegmentEndDate__c != null) ? sub.SBQQ__SegmentEndDate__c : sub.SBQQ__EndDate__c;
    
                if (installationEndDate < subStart || installationStartDate > subEnd) continue;
    
                Date lineStart;
                if (isFirst && installationStartDate < subStart) {
                    lineStart = installationStartDate;
                } else {
                    lineStart = (installationStartDate > subStart) ? installationStartDate : subStart;
                }
    
                Date lineEnd = (installationEndDate < subEnd) ? installationEndDate : subEnd;
    
                Boolean needsProration = (lineStart > subStart || lineEnd < subEnd || (isFirst && installationStartDate < subStart));
    
                Decimal netTotal = needsProration
                    ? calculateProratedAmount(sub.SBQQ__NetPrice__c, subStart, subEnd, lineStart, lineEnd)
                    : sub.SBQQ__NetPrice__c;
    
                Logger.info('Creating line for Product: ' + sub.SBQQ__Product__r.Name +
                            ', Proration: ' + needsProration +
                            ', Line Start: ' + lineStart + ', Line End: ' + lineEnd +
                            ', Net Total: ' + netTotal);
    
                instLines.add(new Installation_Line__c(
                    Name = sub.SBQQ__Product__r.Name,
                    Installation__c = inst.Id,
                    Subscription__c = sub.Id,
                    Quote_Line__c = sub.SBQQ__QuoteLine__c,
                    Product__c = sub.SBQQ__Product__c,
                    Start_Date__c = lineStart,
                    End_Date__c = lineEnd,
                    CurrencyIsoCode = sub.CurrencyIsoCode,
                    Net_Total__c = netTotal
                ));
    
                isFirst = false;
            }
        }
    
        if (!instLines.isEmpty()) {
            Logger.info('Total Installation Lines to insert: ' + instLines.size());
            insert instLines;
            Logger.info('Inserted Installation Lines for Installation: ' + inst.Id);
            Logger.saveLog();
        } else {
            Logger.warn('No Installation Lines generated for Installation: ' + inst.Id);
            Logger.saveLog();
        }
    
        Logger.info('--- END createInstallationLines for Installation: ' + inst.Id + ' ---');
        Logger.saveLog();
    }
	
    @TestVisible
    private static Decimal calculateProratedAmount(Decimal netPrice, Date segStart, Date segEnd, Date lineStart, Date lineEnd) {
        try {
            Boolean isMonthlyAligned =
                segStart.day() == 1 &&
                segEnd == segStart.addMonths(segStart.monthsBetween(segEnd)).addDays(-1) &&
                lineStart.day() == 1 &&
                lineEnd == lineStart.addMonths(lineStart.monthsBetween(lineEnd)).addDays(-1);
    
            if (isMonthlyAligned) {
                Decimal totalMonths = (Decimal) segStart.monthsBetween(segEnd) + 1;
                Decimal lineMonths = (Decimal) lineStart.monthsBetween(lineEnd) + 1;
                return (lineMonths / totalMonths) * netPrice;
            } else {
                Decimal totalDays = segStart.daysBetween(segEnd) + 1;
                Decimal lineDays = lineStart.daysBetween(lineEnd) + 1;
                return (lineDays / totalDays) * netPrice;
            }
        } catch (Exception ex) {
            Logger.error('Error in calculateProratedAmount: ' + ex.getMessage() + '\n' + ex.getStackTraceString());
            Logger.saveLog();
            return 0;
        }
    }
}