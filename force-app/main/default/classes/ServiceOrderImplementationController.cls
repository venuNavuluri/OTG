public with sharing class ServiceOrderImplementationController {
    public class WorkResponse {
        @AuraEnabled public OrderSummary orderSummary;
        @AuraEnabled public List<PackageSummary> packages = new List<PackageSummary>();
        @AuraEnabled public List<InstallationWork> installations = new List<InstallationWork>();
    }

    public class OrderSummary {
        @AuraEnabled public Id serviceOrderId;
        @AuraEnabled public String serviceOrderNumber;
        @AuraEnabled public String serviceOrderStatus;
        @AuraEnabled public Id subscriptionOrderId;
        @AuraEnabled public String subscriptionOrderNumber;
        @AuraEnabled public String subscriptionOrderStatus;
        @AuraEnabled public Id quoteId;
        @AuraEnabled public String quoteNumber;
        @AuraEnabled public String quoteType;
        @AuraEnabled public Boolean requiresServiceOrder;
        @AuraEnabled public Id contractId;
        @AuraEnabled public String contractNumber;
        @AuraEnabled public Date contractStartDate;
        @AuraEnabled public Date contractEndDate;
        @AuraEnabled public Boolean serviceImplementationCompleted;
    }

    public class PackageSummary {
        @AuraEnabled public Id packageId;
        @AuraEnabled public String packageName;
        @AuraEnabled public Integer totalLines = 0;
        @AuraEnabled public Integer completedLines = 0;
    }

    public class InstallationWork {
        @AuraEnabled public Id installationId;
        @AuraEnabled public String installationName;
        @AuraEnabled public String vesselName;
        @AuraEnabled public String imo;
        @AuraEnabled public Id packageId;
        @AuraEnabled public String packageName;
        @AuraEnabled public List<LineWork> lines = new List<LineWork>();
    }

    public class LineWork {
        @AuraEnabled public Id lineId;
        @AuraEnabled public String productName;
        @AuraEnabled public String action;
        @AuraEnabled public String status;
        @AuraEnabled public Date completedDate;
        @AuraEnabled public Decimal netTotal;
    }

    @AuraEnabled(cacheable=true)
    public static WorkResponse getImplementationWork(Id orderId) {
        if (orderId == null) {
            throw new AuraHandledException('Order Id is required.');
        }

        OrderContext context = resolveOrderContext(orderId);
        enforceImplementationAllowed(context);
        WorkResponse response = new WorkResponse();
        response.orderSummary = buildOrderSummary(context);
        if (context.subscriptionOrderId == null) {
            return response;
        }

        Set<Id> packageIds = fetchQuotePackageIds(context.quoteId);

        List<Installation_Line__c> lines = fetchImplementationLines(context.subscriptionOrderId, packageIds);
        response.installations = buildInstallationWork(lines);
        response.packages = buildPackageSummaries(response.installations);
        return response;
    }

    @AuraEnabled
    public static WorkResponse completeLines(Id orderId, List<Id> installationLineIds) {
        enforceImplementationAllowed(orderId);
        return completeLineIds(orderId, installationLineIds, Date.today());
    }

    @AuraEnabled
    public static WorkResponse completeLinesWithDate(Id orderId, List<Id> installationLineIds, Date completionDate) {
        return completeLineIds(orderId, installationLineIds, completionDate);
    }

    private static WorkResponse completeLineIds(Id orderId, List<Id> installationLineIds, Date completionDate) {
        if (installationLineIds == null || installationLineIds.isEmpty()) {
            return getImplementationWork(orderId);
        }
        Date resolvedCompletionDate = completionDate == null ? Date.today() : completionDate;
        OrderContext context = resolveOrderContext(orderId);
        enforceImplementationAllowed(context);
        enforceCompletionDateWithinContract(context, resolvedCompletionDate);
        InstallationProductUpdateService.completeImplementationLines(new Set<Id>(installationLineIds), orderId, resolvedCompletionDate);
        return getImplementationWork(orderId);
    }

    @AuraEnabled
    public static WorkResponse completeInstallation(Id orderId, Id installationId) {
        return completeInstallationWithDate(orderId, installationId, Date.today());
    }

    @AuraEnabled
    public static WorkResponse completeInstallationWithDate(Id orderId, Id installationId, Date completionDate) {
        if (installationId == null) {
            throw new AuraHandledException('Installation Id is required.');
        }
        OrderContext context = resolveOrderContext(orderId);
        Set<Id> packageIds = fetchQuotePackageIds(context.quoteId);
        List<Id> lineIds = new List<Id>();
        for (Installation_Line__c line : fetchPendingImplementationLines(context.subscriptionOrderId, packageIds, installationId, null)) {
            lineIds.add(line.Id);
        }
        return completeLineIds(orderId, lineIds, completionDate);
    }

    @AuraEnabled
    public static WorkResponse completePackage(Id orderId, Id packageId) {
        return completePackageWithDate(orderId, packageId, Date.today());
    }

    @AuraEnabled
    public static WorkResponse completePackageWithDate(Id orderId, Id packageId, Date completionDate) {
        if (packageId == null) {
            throw new AuraHandledException('Package Id is required.');
        }
        OrderContext context = resolveOrderContext(orderId);
        Set<Id> packageIds = fetchQuotePackageIds(context.quoteId);
        if (!packageIds.contains(packageId)) {
            return getImplementationWork(orderId);
        }
        List<Id> lineIds = new List<Id>();
        for (Installation_Line__c line : fetchPendingImplementationLines(context.subscriptionOrderId, packageIds, null, packageId)) {
            lineIds.add(line.Id);
        }
        return completeLineIds(orderId, lineIds, completionDate);
    }

    @AuraEnabled
    public static WorkResponse completeServiceOrder(Id orderId) {
        if (orderId == null) {
            throw new AuraHandledException('Order Id is required.');
        }
        OrderContext context = resolveOrderContext(orderId);
        enforceImplementationAllowed(context);
        Set<Id> packageIds = fetchQuotePackageIds(context.quoteId);
        Integer pendingCount = fetchPendingImplementationLines(context.subscriptionOrderId, packageIds, null, null).size();
        if (pendingCount > 0) {
            throw new AuraHandledException('Service Order still has pending implementation lines.');
        }
        update new Order(Id = orderId, Service_Implementation_Completed__c = true);
        return getImplementationWork(orderId);
    }

    private static List<Installation_Line__c> fetchImplementationLines(Id subscriptionOrderId, Set<Id> packageIds) {
        return [
            SELECT Id, Name, Installation__c, Installation__r.Name, Installation__r.Vessel_Name__r.Name,
                   Installation__r.Vessel_IMO__c, Installation__r.Package__c, Installation__r.Package__r.Name,
                   Product__r.Name, Product__r.Addendum_Requires_SOW__c,
                   Change_Action__c, Implementation_Status__c,
                   Implementation_Completed_Date__c, Net_Total__c
            FROM Installation_Line__c
            WHERE Change_Action__c IN ('Add Product', 'Remove Product')
              AND (Source_Subscription_Order__c = :subscriptionOrderId OR Installation__r.Package__c IN :packageIds)
              AND Product__r.Addendum_Requires_SOW__c = 'Yes'
              AND Installation__r.Installation_Order_Status__c NOT IN ('Terminated', 'Future Terminated', 'Termination Pending')
            ORDER BY Installation__r.Package__r.Name, Installation__r.Name, Product__r.Name
        ];
    }

    private static Set<Id> fetchQuotePackageIds(Id quoteId) {
        Set<Id> packageIds = new Set<Id>();
        if (quoteId == null) {
            return packageIds;
        }
        for (Package__c pkg : [
            SELECT Id
            FROM Package__c
            WHERE Quote__c = :quoteId
              AND Product_Change_Type__c IN ('Products Added & Removed', 'Product Removed', 'New Product Added')
        ]) {
            packageIds.add(pkg.Id);
        }
        return packageIds;
    }

    private static List<Installation_Line__c> fetchPendingImplementationLines(
        Id subscriptionOrderId,
        Set<Id> packageIds,
        Id installationId,
        Id packageId
    ) {
        List<Installation_Line__c> scopedLines = [
            SELECT Id, Installation__c, Installation__r.Package__c
            FROM Installation_Line__c
            WHERE Change_Action__c IN ('Add Product', 'Remove Product')
              AND Implementation_Status__c = 'Pending Implementation'
              AND (Source_Subscription_Order__c = :subscriptionOrderId OR Installation__r.Package__c IN :packageIds)
              AND Product__r.Addendum_Requires_SOW__c = 'Yes'
              AND Installation__r.Installation_Order_Status__c NOT IN ('Terminated', 'Future Terminated', 'Termination Pending')
        ];
        List<Installation_Line__c> filteredLines = new List<Installation_Line__c>();
        for (Installation_Line__c line : scopedLines) {
            if (installationId != null && line.Installation__c != installationId) {
                continue;
            }
            if (packageId != null && line.Installation__r.Package__c != packageId) {
                continue;
            }
            filteredLines.add(line);
        }
        return filteredLines;
    }

    private static List<InstallationWork> buildInstallationWork(List<Installation_Line__c> lines) {
        Map<Id, InstallationWork> byInstallation = new Map<Id, InstallationWork>();
        for (Installation_Line__c line : lines) {
            if (!byInstallation.containsKey(line.Installation__c)) {
                InstallationWork work = new InstallationWork();
                work.installationId = line.Installation__c;
                work.installationName = line.Installation__r.Name;
                work.vesselName = line.Installation__r.Vessel_Name__r != null ? line.Installation__r.Vessel_Name__r.Name : '';
                work.imo = line.Installation__r.Vessel_IMO__c;
                work.packageId = line.Installation__r.Package__c;
                work.packageName = line.Installation__r.Package__r != null ? line.Installation__r.Package__r.Name : '';
                byInstallation.put(line.Installation__c, work);
            }

            LineWork lineWork = new LineWork();
            lineWork.lineId = line.Id;
            lineWork.productName = line.Product__r != null ? line.Product__r.Name : line.Name;
            lineWork.action = String.isBlank(line.Change_Action__c) ? 'Add Product' : line.Change_Action__c;
            lineWork.status = String.isBlank(line.Implementation_Status__c) ? 'Completed' : line.Implementation_Status__c;
            lineWork.completedDate = line.Implementation_Completed_Date__c;
            lineWork.netTotal = line.Net_Total__c;
            byInstallation.get(line.Installation__c).lines.add(lineWork);
        }
        return byInstallation.values();
    }

    private static List<PackageSummary> buildPackageSummaries(List<InstallationWork> installations) {
        Map<Id, PackageSummary> byPackage = new Map<Id, PackageSummary>();
        for (InstallationWork installation : installations) {
            if (!byPackage.containsKey(installation.packageId)) {
                PackageSummary summary = new PackageSummary();
                summary.packageId = installation.packageId;
                summary.packageName = installation.packageName;
                byPackage.put(installation.packageId, summary);
            }
            PackageSummary summary = byPackage.get(installation.packageId);
            for (LineWork line : installation.lines) {
                summary.totalLines++;
                if (line.status == 'Completed') {
                    summary.completedLines++;
                }
            }
        }
        return byPackage.values();
    }

    private static OrderSummary buildOrderSummary(OrderContext context) {
        OrderSummary summary = new OrderSummary();
        summary.serviceOrderId = context.serviceOrderId;
        summary.serviceOrderNumber = context.serviceOrderNumber;
        summary.serviceOrderStatus = context.serviceOrderStatus;
        summary.subscriptionOrderId = context.subscriptionOrderId;
        summary.subscriptionOrderNumber = context.subscriptionOrderNumber;
        summary.subscriptionOrderStatus = context.subscriptionOrderStatus;
        summary.quoteId = context.quoteId;
        summary.quoteNumber = context.quoteNumber;
        summary.quoteType = context.quoteType;
        summary.requiresServiceOrder = context.requiresServiceOrder;
        summary.contractId = context.contractId;
        summary.contractNumber = context.contractNumber;
        summary.contractStartDate = context.contractStartDate;
        summary.contractEndDate = context.contractEndDate;
        summary.serviceImplementationCompleted = context.serviceImplementationCompleted;
        return summary;
    }

    private static void enforceImplementationAllowed(Id orderId) {
        if (orderId == null) {
            throw new AuraHandledException('Order Id is required.');
        }
        enforceImplementationAllowed(resolveOrderContext(orderId));
    }

    private static void enforceImplementationAllowed(OrderContext context) {
        if (context == null) {
            throw new AuraHandledException('Order context is required.');
        }
        if (context.quoteType == 'Amendment' &&
            context.requiresServiceOrder == true &&
            context.subscriptionOrderStatus != 'Activated') {
            throw new AuraHandledException(
                'Subscription Order must be Activated before Service Order implementation can be completed.'
            );
        }
    }

    private static void enforceCompletionDateWithinContract(OrderContext context, Date completionDate) {
        if (context == null || completionDate == null) {
            return;
        }
        if (context.contractStartDate != null && completionDate < context.contractStartDate) {
            throw new AuraHandledException(
                'Completion Date must be within the contract period: ' +
                String.valueOf(context.contractStartDate) + ' to ' + String.valueOf(context.contractEndDate) + '.'
            );
        }
        if (context.contractEndDate != null && completionDate > context.contractEndDate) {
            throw new AuraHandledException(
                'Completion Date must be within the contract period: ' +
                String.valueOf(context.contractStartDate) + ' to ' + String.valueOf(context.contractEndDate) + '.'
            );
        }
    }

    private static OrderContext resolveOrderContext(Id orderId) {
        Order ord = [
            SELECT Id, OrderNumber, Status, Type, OpportunityId, ContractId, Service_Implementation_Completed__c,
                   SBQQ__Quote__c, SBQQ__Quote__r.Name, SBQQ__Quote__r.SBQQ__Type__c, SBQQ__Quote__r.Requires_Service_Order__c,
                   SBQQ__Quote__r.SBQQ__MasterContract__c,
                   SBQQ__Quote__r.SBQQ__MasterContract__r.ContractNumber,
                   SBQQ__Quote__r.SBQQ__MasterContract__r.StartDate,
                   SBQQ__Quote__r.SBQQ__MasterContract__r.EndDate,
                   Subscription_Order__c, Subscription_Order__r.OrderNumber, Subscription_Order__r.Status,
                   Subscription_Order__r.SBQQ__Quote__c, Subscription_Order__r.SBQQ__Quote__r.Name,
                   Subscription_Order__r.SBQQ__Quote__r.SBQQ__Type__c,
                   Subscription_Order__r.SBQQ__Quote__r.Requires_Service_Order__c,
                   Subscription_Order__r.SBQQ__Quote__r.SBQQ__MasterContract__c,
                   Subscription_Order__r.SBQQ__Quote__r.SBQQ__MasterContract__r.ContractNumber,
                   Subscription_Order__r.SBQQ__Quote__r.SBQQ__MasterContract__r.StartDate,
                   Subscription_Order__r.SBQQ__Quote__r.SBQQ__MasterContract__r.EndDate
            FROM Order
            WHERE Id = :orderId
            LIMIT 1
        ];

        OrderContext context = new OrderContext();
        context.serviceOrderId = ord.Id;
        context.serviceOrderNumber = ord.OrderNumber;
        context.serviceOrderStatus = ord.Status;
        context.serviceImplementationCompleted = ord.Service_Implementation_Completed__c;

        if (ord.Type == 'Service Delivery' && ord.Subscription_Order__c != null) {
            context.subscriptionOrderId = ord.Subscription_Order__c;
            context.subscriptionOrderNumber = ord.Subscription_Order__r.OrderNumber;
            context.subscriptionOrderStatus = ord.Subscription_Order__r.Status;
            context.quoteId = ord.Subscription_Order__r.SBQQ__Quote__c;
            context.quoteNumber = ord.Subscription_Order__r.SBQQ__Quote__r != null ? ord.Subscription_Order__r.SBQQ__Quote__r.Name : '';
            context.quoteType = ord.Subscription_Order__r.SBQQ__Quote__r != null ? ord.Subscription_Order__r.SBQQ__Quote__r.SBQQ__Type__c : '';
            context.requiresServiceOrder = ord.Subscription_Order__r.SBQQ__Quote__r != null && ord.Subscription_Order__r.SBQQ__Quote__r.Requires_Service_Order__c == true;
            context.contractId = ord.Subscription_Order__r.SBQQ__Quote__r != null ? ord.Subscription_Order__r.SBQQ__Quote__r.SBQQ__MasterContract__c : null;
            context.contractNumber = ord.Subscription_Order__r.SBQQ__Quote__r != null && ord.Subscription_Order__r.SBQQ__Quote__r.SBQQ__MasterContract__r != null
                ? ord.Subscription_Order__r.SBQQ__Quote__r.SBQQ__MasterContract__r.ContractNumber
                : '';
            context.contractStartDate = ord.Subscription_Order__r.SBQQ__Quote__r != null && ord.Subscription_Order__r.SBQQ__Quote__r.SBQQ__MasterContract__r != null
                ? ord.Subscription_Order__r.SBQQ__Quote__r.SBQQ__MasterContract__r.StartDate
                : null;
            context.contractEndDate = ord.Subscription_Order__r.SBQQ__Quote__r != null && ord.Subscription_Order__r.SBQQ__Quote__r.SBQQ__MasterContract__r != null
                ? ord.Subscription_Order__r.SBQQ__Quote__r.SBQQ__MasterContract__r.EndDate
                : null;
        } else {
            context.subscriptionOrderId = ord.Id;
            context.subscriptionOrderNumber = ord.OrderNumber;
            context.subscriptionOrderStatus = ord.Status;
            context.quoteId = ord.SBQQ__Quote__c;
            context.quoteNumber = ord.SBQQ__Quote__r != null ? ord.SBQQ__Quote__r.Name : '';
            context.quoteType = ord.SBQQ__Quote__r != null ? ord.SBQQ__Quote__r.SBQQ__Type__c : '';
            context.requiresServiceOrder = ord.SBQQ__Quote__r != null && ord.SBQQ__Quote__r.Requires_Service_Order__c == true;
            context.contractId = ord.SBQQ__Quote__r != null ? ord.SBQQ__Quote__r.SBQQ__MasterContract__c : ord.ContractId;
            context.contractNumber = ord.SBQQ__Quote__r != null && ord.SBQQ__Quote__r.SBQQ__MasterContract__r != null
                ? ord.SBQQ__Quote__r.SBQQ__MasterContract__r.ContractNumber
                : '';
            context.contractStartDate = ord.SBQQ__Quote__r != null && ord.SBQQ__Quote__r.SBQQ__MasterContract__r != null
                ? ord.SBQQ__Quote__r.SBQQ__MasterContract__r.StartDate
                : null;
            context.contractEndDate = ord.SBQQ__Quote__r != null && ord.SBQQ__Quote__r.SBQQ__MasterContract__r != null
                ? ord.SBQQ__Quote__r.SBQQ__MasterContract__r.EndDate
                : null;
        }
        return context;
    }

    private class OrderContext {
        Id serviceOrderId;
        String serviceOrderNumber;
        String serviceOrderStatus;
        Boolean serviceImplementationCompleted;
        Id subscriptionOrderId;
        String subscriptionOrderNumber;
        String subscriptionOrderStatus;
        Id quoteId;
        String quoteNumber;
        String quoteType;
        Boolean requiresServiceOrder;
        Id contractId;
        String contractNumber;
        Date contractStartDate;
        Date contractEndDate;
    }
}
