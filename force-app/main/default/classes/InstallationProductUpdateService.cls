public with sharing class InstallationProductUpdateService {
    // Logger for tracking execution
    private static final String LOGGER_NAME = 'InstallationProductUpdateService';
    private static Map<Id, Date> orderActivationContext = new Map<Id, Date>();
    private static Map<Id, Date> installationActivationContext = new Map<Id, Date>();
    
    // Wrapper to hold grouped records per Package
    public class PackageGroup {
        @AuraEnabled public Id packageId;
        @AuraEnabled public String packageName;
        @AuraEnabled public Id quoteId;
        @AuraEnabled public Id quoteLineGroupId;
        @AuraEnabled public String productChangeType;
        @AuraEnabled public String currencyIsoCode;
        @AuraEnabled public Id orderId;

        // Flat lists (kept for convenience)
        @AuraEnabled public List<OrderItem> orderItems = new List<OrderItem>();
        @AuraEnabled public List<SBQQ__Subscription__c> subscriptions = new List<SBQQ__Subscription__c>();
        @AuraEnabled public List<Installation__c> installations = new List<Installation__c>();
        @AuraEnabled public List<Sales_Order__c> salesOrders = new List<Sales_Order__c>();

        // Groupings required
        // - Group subscriptions by package: map already keyed by this PackageGroup
        // - Group installations by package: map already keyed by this PackageGroup
        // - Group sales orders by installation: below map indexes SOs by Installation Id
        @AuraEnabled public Map<Id, List<Sales_Order__c>> salesOrdersByInstallation = new Map<Id, List<Sales_Order__c>>();

        public PackageGroup(Package__c p) {
            packageId = p.Id;
            packageName = p.Name;
            quoteId = p.Quote__c;
            quoteLineGroupId = p.Quote_Line_Group__c;
            productChangeType = p.Product_Change_Type__c;
            currencyIsoCode = p.CurrencyIsoCode;
            orderId = p.Order__c;
        }
    }

    // Batch-friendly orchestrator
    public static Map<Id, PackageGroup> processOrders(Set<Id> orderIds) {
        orderActivationContext.clear();
        installationActivationContext.clear();
        if (orderIds == null || orderIds.isEmpty()) {
            return new Map<Id, PackageGroup>();
        }

        // 1) Orders with Master Contract (ordConIdMap pattern)
        List<Order> orders = fetchOrdersWithQuote(orderIds);
        if (orders.isEmpty()) return new Map<Id, PackageGroup>();

        // Build ordConIdMap: Order.Id -> Master Contract Id
        Map<Id, Id> ordConIdMap = buildOrderToMasterContractMap(orders);

        for (Order ord : orders) {
            if (ord.Id != null && ord.EffectiveDate != null) {
                orderActivationContext.put(ord.Id, ord.EffectiveDate);
            }
        }

        // Collect Quote Ids
        Set<Id> quoteIds = collectQuoteIds(orders);
        if (quoteIds.isEmpty()) return new Map<Id, PackageGroup>();

        // 2) Packages (exclude New Package/null)
        List<Package__c> packages = fetchPackagesForQuotes(quoteIds);
        if (packages.isEmpty()) return new Map<Id, PackageGroup>();

        // Initialize per-package wrapper map
        Map<Id, PackageGroup> packageGroups = initPackageGroups(packages, new Map<Id, List<OrderItem>>());

        // 3) OrderItems filtered by Contract Action and grouped by Package via QLG
        //    Only where SBQQ__ContractAction__c IN ('New','Cancel')
        Set<Id> qlgIds = collectQLGIds(packages);
        if (!qlgIds.isEmpty()) {
            List<OrderItem> filteredOrderItems = fetchOrderItemsByQLGAndContractAction(qlgIds);
            // group by package using QLG -> Package lookup
            Map<Id, Id> qlgToPackage = mapQLGToPackageId(packages);
            for (OrderItem oi : filteredOrderItems) {
                Id qlgId = (Id) oi.get('Quote_Line_Group_ID__c');
                Id pkgId = qlgToPackage.get(qlgId);
                if (pkgId != null && packageGroups.containsKey(pkgId)) {
                    packageGroups.get(pkgId).orderItems.add(oi);
                }
            }
        }

        // 4) Attach subscriptions from order items (no extra query)
        attachSubscriptionsFromOrderItems(packageGroups);

        // 5) Fetch Installations using Master Contract Ids (per reference method signature)
        List<Installation__c> installations = fetchInstallationsByContracts(ordConIdMap.values());
        // Group installations by Package
        Map<Id, List<Installation__c>> pkgToInstalls = groupInstallationsByPackage(installations);

        // Attach Installations to corresponding PackageGroup
        for (Id pkgId : packageGroups.keySet()) {
            List<Installation__c> insts = pkgToInstalls.get(pkgId);
            if (insts != null && !insts.isEmpty()) {
                packageGroups.get(pkgId).installations.addAll(insts);
            }
        }

        // 6) Fetch existing Sales Orders for those installations and group by installation
        //    Filter sales orders to only include those related to the current contract and period
        //    that covers order activation date and contract end date
        Set<Id> installationIds = new Set<Id>();
        for (List<Installation__c> insts : pkgToInstalls.values()) {
            for (Installation__c i : insts) installationIds.add(i.Id);
        }
        if (!installationIds.isEmpty()) {
            // Get the contract IDs to filter sales orders properly
            Set<Id> contractIds = new Set<Id>();
            for (Installation__c inst : installations) {
                if (inst.Contract__c != null) {
                    contractIds.add(inst.Contract__c);
                }
            }

            List<Sales_Order__c> soList = fetchFilteredSalesOrdersByContractAndPeriod(installationIds, contractIds, orders);
            Map<Id, List<Sales_Order__c>> instIdToSOs = indexSalesOrdersByInstallation(soList);

            for (Id pkgId : packageGroups.keySet()) {
                PackageGroup grp = packageGroups.get(pkgId);
                List<Installation__c> insts = grp.installations;
                if (insts == null || insts.isEmpty()) continue;

                for (Installation__c inst : insts) {
                    List<Sales_Order__c> sos = instIdToSOs.get(inst.Id);
                    if (sos != null && !sos.isEmpty()) {
                        grp.salesOrders.addAll(sos);
                        grp.salesOrdersByInstallation.put(inst.Id, sos);
                    } else {
                        grp.salesOrdersByInstallation.put(inst.Id, new List<Sales_Order__c>());
                    }
                }
            }
        }

        return packageGroups;
    }

    // Helper: Query Orders incl. Quote->Master Contract
    @TestVisible
    private static List<Order> fetchOrdersWithQuote(Set<Id> orderIds) {
        try {
            return [
                SELECT Id, SBQQ__Quote__c, SBQQ__Quote__r.SBQQ__MasterContract__c, Type, OpportunityId, EffectiveDate
                FROM Order
                WHERE Id IN :orderIds
            ];
        } catch (Exception e) {
            Logger.error(LOGGER_NAME + ' - Error in fetchOrdersWithQuote: ' + e.getMessage());
            Logger.saveLog();
            throw new AuraHandledException(LOGGER_NAME + ' - Error fetching orders: ' + e.getMessage());
        }
    }

    // Helper: Build OrderId -> MasterContractId map (ordConIdMap)
    @TestVisible
    private static Map<Id, Id> buildOrderToMasterContractMap(List<Order> orders) {
        Map<Id, Id> ordConIdMap = new Map<Id, Id>();
        for (Order ord : orders) {
            if (ord.SBQQ__Quote__r != null && ord.SBQQ__Quote__r.SBQQ__MasterContract__c != null) {
                ordConIdMap.put(ord.Id, ord.SBQQ__Quote__r.SBQQ__MasterContract__c);
            }
        }
        return ordConIdMap;
    }

    // Helper: Collect Quote Ids from Orders
    @TestVisible
    private static Set<Id> collectQuoteIds(List<Order> orders) {
        Set<Id> quoteIds = new Set<Id>();
        for (Order o : orders) {
            if (o.SBQQ__Quote__c != null) quoteIds.add(o.SBQQ__Quote__c);
        }
        return quoteIds;
    }

    // Helper: Query Packages for Quotes, excluding Product Change Type = 'New Package' and null
    @TestVisible
    private static List<Package__c> fetchPackagesForQuotes(Set<Id> quoteIds) {
        try {
            Set<String> excludedChangeTypes = new Set<String>{ 'New Package', 'No Change' };
            return [
                SELECT
                    Id,
                    Name,
                    CurrencyIsoCode,
                    Quote__c,
                    Quote_Line_Group__c,
                    Product_Change_Type__c,
                    // additional fields referenced elsewhere in repo
                    Order__c,
                    Installation_Quantity__c,
                    Installation_Change_Type__c,
                    Prior_Installation_Quantity__c,
                    Products__c,
                    InstallationCost__c,
                    Temp_Quote_Line_Group__c
                FROM Package__c
                WHERE Quote__c IN :quoteIds
                  AND Product_Change_Type__c != null
                  AND Product_Change_Type__c NOT IN :excludedChangeTypes
            ];
        } catch (Exception e) {
            Logger.error(LOGGER_NAME + ' - Error in fetchPackagesForQuotes: ' + e.getMessage());
            Logger.saveLog();
            throw new AuraHandledException(LOGGER_NAME + ' - Error fetching packages: ' + e.getMessage());
        }
    }

    // Helper: Collect QLG Ids from Packages
    @TestVisible
    private static Set<Id> collectQLGIds(List<Package__c> packages) {
        Set<Id> qlgIds = new Set<Id>();
        for (Package__c p : packages) {
            if (p.Quote_Line_Group__c != null) qlgIds.add(p.Quote_Line_Group__c);
        }
        return qlgIds;
    }

    // Helper: Query OrderItems by QLG with subscription and restricted to Contract Actions New/Cancel
    @TestVisible
    private static List<OrderItem> fetchOrderItemsByQLGAndContractAction(Set<Id> qlgIds) {
        return [
            SELECT
                Id,
                OrderId,
                Product2Id,
                PricebookEntryId,
                Quantity,
                UnitPrice,
                ListPrice,
                TotalPrice,
                CurrencyIsoCode,
                Quote_Line_Group_ID__c,
                SBQQ__ContractAction__c,
                // Subscription already available on OrderItem (no extra query needed)
                SBQQ__Subscription__c,
                SBQQ__Subscription__r.Id,
                SBQQ__Subscription__r.Name,
                SBQQ__Subscription__r.SBQQ__Product__c,
                SBQQ__Subscription__r.SBQQ__Product__r.Name,
                SBQQ__Subscription__r.SBQQ__NetPrice__c,
                SBQQ__Subscription__r.SBQQ__Contract__c,
                SBQQ__Subscription__r.Package__c,
                SBQQ__Subscription__r.SBQQ__SegmentStartDate__c,
                SBQQ__Subscription__r.SBQQ__SegmentEndDate__c,
                SBQQ__Subscription__r.CurrencyIsoCode,
                SBQQ__Subscription__r.SBQQ__StartDate__c,
                SBQQ__Subscription__r.SBQQ__EndDate__c,
                SBQQ__Subscription__r.SBQQ__QuoteLine__c,
                SBQQ__Subscription__r.SBQQ__QuoteLine__r.Change_Type__c
            FROM OrderItem
            WHERE Quote_Line_Group_ID__c IN :qlgIds
              AND SBQQ__ContractAction__c IN ('New','Cancel')
        ];
    }

    // Helper: Build QLG -> Package Id map
    @TestVisible
    private static Map<Id, Id> mapQLGToPackageId(List<Package__c> packages) {
        Map<Id, Id> m = new Map<Id, Id>();
        for (Package__c p : packages) {
            if (p.Quote_Line_Group__c != null) {
                m.put(p.Quote_Line_Group__c, p.Id);
            }
        }
        return m;
    }

    // Helper: Fetch Installations by Contract Ids (matches reference signature/logic)
    @TestVisible
    private static List<Installation__c> fetchInstallationsByContracts(List<Id> contractIds) {
        try {
            if (contractIds == null || contractIds.isEmpty()) return new List<Installation__c>();
            return [
                SELECT Id, Name, Contract__c, Order__c, Quote__c, Package__c,
                       Installation_Start_Date__c, Installation_End_Date__c,
                       (SELECT Id, Name, Product__c FROM Installation_Lines__r)
                FROM Installation__c
                WHERE Contract__c IN :contractIds
                  AND Installation_Order_Status__c = 'Active'
                  AND Change_Package_Status__c != 'In Progress'
            ];
        } catch (Exception e) {
            Logger.error(LOGGER_NAME + ' - Error in fetchInstallationsByContracts: ' + e.getMessage());
            Logger.saveLog();
            throw new AuraHandledException(LOGGER_NAME + ' - Error fetching installations: ' + e.getMessage());
        }
    }

    // Helper: Group Installations by Package
    @TestVisible
    private static Map<Id, List<Installation__c>> groupInstallationsByPackage(List<Installation__c> instList) {
        Map<Id, List<Installation__c>> mapData = new Map<Id, List<Installation__c>>();
        for (Installation__c inst : instList) {
            if (!mapData.containsKey(inst.Package__c)) {
                mapData.put(inst.Package__c, new List<Installation__c>());
            }
            mapData.get(inst.Package__c).add(inst);
        }
        return mapData;
    }

    // Helper: Fetch Sales Orders by Installation with contract and date filtering
    @TestVisible
    private static List<Sales_Order__c> fetchFilteredSalesOrdersByContractAndPeriod(Set<Id> installationIds, Set<Id> contractIds, List<Order> orders) {
        if (installationIds == null || installationIds.isEmpty() || contractIds == null || contractIds.isEmpty()) {
            return new List<Sales_Order__c>();
        }

        return [
            SELECT Id, Name, Start_Date__c, End_Date__c, Installation__c, Status__c, Contract__c, Invoice_Account__c, CurrencyIsoCode
            FROM Sales_Order__c
            WHERE Installation__c IN :installationIds
              AND Contract__c IN :contractIds
              AND End_Date__c >= :System.today()
        ];
    }

    // Helper: Index Sales Orders by Installation Id
    @TestVisible
    private static Map<Id, List<Sales_Order__c>> indexSalesOrdersByInstallation(List<Sales_Order__c> soList) {
        Map<Id, List<Sales_Order__c>> mapData = new Map<Id, List<Sales_Order__c>>();
        for (Sales_Order__c so : soList) {
            if (!mapData.containsKey(so.Installation__c)) {
                mapData.put(so.Installation__c, new List<Sales_Order__c>());
            }
            mapData.get(so.Installation__c).add(so);
        }
        return mapData;
    }

    // Helper: Index OrderItems by QLG
    @TestVisible
    private static Map<Id, List<OrderItem>> indexOrderItemsByQLG(List<OrderItem> orderItems) {
        Map<Id, List<OrderItem>> qlgToOrderItems = new Map<Id, List<OrderItem>>();
        for (OrderItem oi : orderItems) {
            Id qlgId = oi.Quote_Line_Group_ID__c;
            if (qlgId == null) continue;
            if (!qlgToOrderItems.containsKey(qlgId)) {
                qlgToOrderItems.put(qlgId, new List<OrderItem>());
            }
            qlgToOrderItems.get(qlgId).add(oi);
        }
        return qlgToOrderItems;
    }

    // Helper: Initialize Package groups and attach OrderItems by matching QLG
    @TestVisible
    private static Map<Id, PackageGroup> initPackageGroups(List<Package__c> packages, Map<Id, List<OrderItem>> qlgToOrderItems) {
        Map<Id, PackageGroup> packageGroups = new Map<Id, PackageGroup>();
        for (Package__c p : packages) {
            PackageGroup grp = new PackageGroup(p);
            List<OrderItem> items = qlgToOrderItems.get(p.Quote_Line_Group__c);
            if (items != null && !items.isEmpty()) {
                grp.orderItems.addAll(items);
            }
            packageGroups.put(p.Id, grp);
        }
        return packageGroups;
    }

    // Helper: Attach subscriptions from OrderItem (no separate query)
    // Also builds grouping by package implicitly by adding into the package's group wrapper.
    @TestVisible
    private static void attachSubscriptionsFromOrderItems(Map<Id, PackageGroup> packageGroups) {
        // Collect all subscription IDs from order items first
        Set<Id> subIds = new Set<Id>();
        for (PackageGroup grp : packageGroups.values()) {
            for (OrderItem oi : grp.orderItems) {
                Id subId = oi.SBQQ__Subscription__c;
                if (subId != null) {
                    subIds.add(subId);
                }
            }
        }
        
        // Fetch subscriptions in bulk to avoid N+1 issues
        Map<Id, SBQQ__Subscription__c> subMap = new Map<Id, SBQQ__Subscription__c>();
        if (!subIds.isEmpty()) {
            List<SBQQ__Subscription__c> subs = [
                SELECT Id, Name, SBQQ__Product__c, SBQQ__Product__r.Name, SBQQ__NetPrice__c,
                       SBQQ__Contract__c, Package__c, SBQQ__SegmentStartDate__c, SBQQ__SegmentEndDate__c,
                       CurrencyIsoCode, SBQQ__StartDate__c, SBQQ__EndDate__c, SBQQ__OrderProduct__r.SBQQ__ContractAction__c,
                       SBQQ__QuoteLine__c, SBQQ__QuoteLine__r.Change_Type__c
                FROM SBQQ__Subscription__c
                WHERE Id IN :subIds
            ];
            for (SBQQ__Subscription__c sub : subs) {
                subMap.put(sub.Id, sub);
            }
        }
        
        // Now associate subscriptions with package groups
        for (PackageGroup grp : packageGroups.values()) {
            Set<Id> seenSubIds = new Set<Id>(); // avoid duplicates
            for (OrderItem oi : grp.orderItems) {
                Id subId = (Id) oi.get('SBQQ__Subscription__c');
                if (subId != null && !seenSubIds.contains(subId)) {
                    SBQQ__Subscription__c sub = subMap.get(subId);
                    if (sub != null) {
                        grp.subscriptions.add(sub);
                        seenSubIds.add(subId);
                    }
                }
            }
        }
    }

    // Helper method to calculate prorated amount (similar to InstallationLineService)
    @TestVisible
    private static Decimal calculateProratedAmount(Decimal netPrice, Date startDate, Date endDate, Date lineStart, Date lineEnd) {
        if (netPrice == null || startDate == null || endDate == null || lineStart == null || lineEnd == null) {
            return 0;
        }

        Installation_Line__c tempLine = new Installation_Line__c(
            Start_Date__c = startDate,
            End_Date__c = endDate,
            Net_Total__c = netPrice
        );

        Sales_Order__c tempOrder = new Sales_Order__c(
            Start_Date__c = lineStart,
            End_Date__c = lineEnd
        );

        Double result = SalesOrderGeneratorService.calculateProratedAmount(tempLine, tempOrder);
        return (result == null) ? 0 : (Decimal)result;
    }

    // Method to process sales orders for newly created installation lines
    // This mirrors the logic from InstallationLineService.processSalesOrders but with enhanced handling for multi-year contracts
    @TestVisible
    private static void processSalesOrders(List<Installation_Line__c> instLineList) {
        if (instLineList == null || instLineList.isEmpty()) {
            return;
        }

        Map<Id, List<Installation_Line__c>> installationLineMap = new Map<Id, List<Installation_Line__c>>();
        Set<Id> installationIds = new Set<Id>();
        for (Installation_Line__c line : instLineList) {
            if (line.Installation__c == null) {
                continue;
            }
            if (!installationLineMap.containsKey(line.Installation__c)) {
                installationLineMap.put(line.Installation__c, new List<Installation_Line__c>());
            }
            installationLineMap.get(line.Installation__c).add(line);
            installationIds.add(line.Installation__c);
        }

        if (installationIds.isEmpty()) {
            return;
        }

        Map<Id, Installation__c> installationDetails = new Map<Id, Installation__c>(
            [
                SELECT Id, Contract__c, Order__c
                FROM Installation__c
                WHERE Id IN :installationIds
            ]
        );

        Set<Id> contractIds = new Set<Id>();
        for (Installation__c inst : installationDetails.values()) {
            if (inst.Contract__c != null) {
                contractIds.add(inst.Contract__c);
            }
        }

        if (contractIds.isEmpty()) {
            return;
        }

        List<Sales_Order__c> soList = [
            SELECT Id,
                   Name,
                   Start_Date__c,
                   End_Date__c,
                   Installation__c,
                   Status__c,
                   Contract__c,
                   Invoice_Account__c,
                   CurrencyIsoCode
            FROM Sales_Order__c
            WHERE Installation__c IN :installationIds
              AND Contract__c IN :contractIds
        ];

        if (soList.isEmpty()) {
            return;
        }

        List<Sales_Order_Item__c> salesOrderItemsToCreate = new List<Sales_Order_Item__c>();
        List<Sales_Order__c> newSalesOrders = new List<Sales_Order__c>();
        List<Sales_Order_Item__c> pendingItemsForNewOrders = new List<Sales_Order_Item__c>();
        List<Sales_Order__c> pendingParents = new List<Sales_Order__c>();

        for (Sales_Order__c salesOrder : soList) {
            List<Installation_Line__c> relatedLines = installationLineMap.get(salesOrder.Installation__c);
            if (relatedLines == null || relatedLines.isEmpty()) {
                continue;
            }

            Installation__c instRecord = installationDetails.get(salesOrder.Installation__c);
            if (instRecord == null || instRecord.Contract__c == null || instRecord.Contract__c != salesOrder.Contract__c) {
                continue;
            }

            Date activationDate = installationActivationContext.get(salesOrder.Installation__c);
            if (activationDate == null && instRecord.Order__c != null) {
                activationDate = orderActivationContext.get(instRecord.Order__c);
            }
            if (activationDate == null) {
                activationDate = salesOrder.Start_Date__c;
            }
            if (activationDate == null) {
                continue;
            }
            if (salesOrder.End_Date__c != null && salesOrder.End_Date__c < activationDate) {
                continue;
            }

            Date orderStart = salesOrder.Start_Date__c;
            Date orderEnd = salesOrder.End_Date__c;

            for (Installation_Line__c line : relatedLines) {
                if (line.Start_Date__c == null || line.End_Date__c == null || line.Net_Total__c == null) {
                    continue;
                }

                Date resolvedOrderStart = (orderStart != null) ? orderStart : line.Start_Date__c;
                Date resolvedOrderEnd = (orderEnd != null) ? orderEnd : line.End_Date__c;
                if (resolvedOrderStart == null || resolvedOrderEnd == null) {
                    continue;
                }

                if (salesOrder.Status__c == 'Unbilled' || salesOrder.Status__c == 'Pending Approval') {
                    Date overlapStart = resolvedOrderStart;
                    if (line.Start_Date__c != null && line.Start_Date__c > overlapStart) {
                        overlapStart = line.Start_Date__c;
                    }
                    if (activationDate != null && activationDate > overlapStart) {
                        overlapStart = activationDate;
                    }

                    Date overlapEnd = resolvedOrderEnd;
                    if (line.End_Date__c != null && line.End_Date__c < overlapEnd) {
                        overlapEnd = line.End_Date__c;
                    }

                    if (overlapStart != null && overlapEnd != null && overlapStart <= overlapEnd) {
                        Decimal proratedAmount = calculateProratedAmount(
                            line.Net_Total__c,
                            line.Start_Date__c,
                            line.End_Date__c,
                            overlapStart,
                            overlapEnd
                        );

                        Sales_Order_Item__c item = new Sales_Order_Item__c(
                            Name = line.Name,
                            Sales_Order__c = salesOrder.Id,
                            Installation_Line__c = line.Id,
                            Subscription__c = line.Subscription__c,
                            CurrencyIsoCode = line.CurrencyIsoCode,
                            Amount__c = proratedAmount
                        );
                        salesOrderItemsToCreate.add(item);
                    }
                } else if (salesOrder.Status__c == 'Billed') {
                    Date overlapStart = activationDate;
                    if (overlapStart == null) {
                        overlapStart = line.Start_Date__c;
                    } else if (line.Start_Date__c != null && line.Start_Date__c > overlapStart) {
                        overlapStart = line.Start_Date__c;
                    }

                    Date overlapEnd = resolvedOrderEnd;
                    if (line.End_Date__c != null && line.End_Date__c < overlapEnd) {
                        overlapEnd = line.End_Date__c;
                    }

                    if (overlapStart != null && overlapEnd != null && overlapStart <= overlapEnd) {
                        Decimal proratedAmount = calculateProratedAmount(
                            line.Net_Total__c,
                            line.Start_Date__c,
                            line.End_Date__c,
                            overlapStart,
                            overlapEnd
                        );

                        Boolean isCancelLine = (line.Net_Total__c != null && line.Net_Total__c < 0);

                        Sales_Order__c newSalesOrder = new Sales_Order__c(
                            Contract__c = salesOrder.Contract__c,
                            Invoice_Account__c = salesOrder.Invoice_Account__c,
                            Installation__c = salesOrder.Installation__c,
                            Start_Date__c = overlapStart,
                            End_Date__c = overlapEnd,
                            Status__c = 'Pending Approval',
                            CurrencyIsoCode = salesOrder.CurrencyIsoCode,
                            Credit_Note__c = isCancelLine
                        );
                        newSalesOrders.add(newSalesOrder);

                        Sales_Order_Item__c pendingItem = new Sales_Order_Item__c(
                            Name = line.Name,
                            Installation_Line__c = line.Id,
                            Subscription__c = line.Subscription__c,
                            CurrencyIsoCode = line.CurrencyIsoCode,
                            Amount__c = proratedAmount
                        );
                        pendingItemsForNewOrders.add(pendingItem);
                        pendingParents.add(newSalesOrder);
                    }
                }
            }
        }

        if (!newSalesOrders.isEmpty()) {
            insert newSalesOrders;
            for (Integer idx = 0; idx < pendingItemsForNewOrders.size(); idx++) {
                Sales_Order__c parent = pendingParents[idx];
                Sales_Order_Item__c pendingItem = pendingItemsForNewOrders[idx];
                if (parent != null && parent.Id != null) {
                    pendingItem.Sales_Order__c = parent.Id;
                    salesOrderItemsToCreate.add(pendingItem);
                }
            }
        }

        if (!salesOrderItemsToCreate.isEmpty()) {
            insert salesOrderItemsToCreate;
        }
    }

    // Method to create installation lines from subscriptions grouped by packages
    // This method processes the already-fetched subscriptions and creates installation lines
    @TestVisible
    public static List<Installation_Line__c> createInstallationLinesFromSubscriptions(Map<Id, PackageGroup> packageGroups) {
        installationActivationContext.clear();
        List<Installation_Line__c> newInstLines = new List<Installation_Line__c>();
        
        for (PackageGroup pkgGroup : packageGroups.values()) {
            if (pkgGroup.subscriptions.isEmpty()) {
                continue;
            }

            Map<Id, List<Installation__c>> packIdInstMap = groupInstallationsByPackage(pkgGroup.installations);
            if (packIdInstMap.isEmpty() || !packIdInstMap.containsKey(pkgGroup.packageId)) {
                continue;
            }

            Date activationDate = null;
            if (pkgGroup.orderId != null) {
                activationDate = orderActivationContext.get(pkgGroup.orderId);
            }

            for (SBQQ__Subscription__c sub : pkgGroup.subscriptions) {
                if (sub.SBQQ__QuoteLine__c == null) {
                    continue;
                }

                for (Installation__c inst : packIdInstMap.get(pkgGroup.packageId)) {
                    Date instStart = inst.Installation_Start_Date__c;
                    Date instEnd = inst.Installation_End_Date__c;
                    Date subStart = (sub.SBQQ__SegmentStartDate__c != null) ? sub.SBQQ__SegmentStartDate__c : sub.SBQQ__StartDate__c;
                    Date subEnd = (sub.SBQQ__SegmentEndDate__c != null) ? sub.SBQQ__SegmentEndDate__c : sub.SBQQ__EndDate__c;

                    if (instEnd < subStart || instStart > subEnd) {
                        continue;
                    }

                    Date lineStart = (instStart > subStart) ? instStart : subStart;
                    Date lineEnd = (instEnd < subEnd) ? instEnd : subEnd;

                    Installation_Line__c newLine = new Installation_Line__c(
                        Name = sub.SBQQ__Product__r != null ? sub.SBQQ__Product__r.Name : 'Unknown Product',
                        Installation__c = inst.Id,
                        Subscription__c = sub.Id,
                        Quote_Line__c = sub.SBQQ__QuoteLine__c,
                        Product__c = sub.SBQQ__Product__c,
                        Start_Date__c = subStart,
                        End_Date__c = subEnd,
                        CurrencyIsoCode = sub.CurrencyIsoCode,
                        Net_Total__c = sub.SBQQ__OrderProduct__r.SBQQ__ContractAction__c == 'Cancel' ? -sub.SBQQ__NetPrice__c : sub.SBQQ__NetPrice__c
                    );

                    newInstLines.add(newLine);

                    if (activationDate != null) {
                        installationActivationContext.put(inst.Id, activationDate);
                    }
                }
            }
        }

        if (newInstLines.isEmpty()) {
            return newInstLines;
        }

        try {
            insert newInstLines;
        } catch (Exception e) {
            Logger.error(LOGGER_NAME + ' - Error inserting installation lines: ' + e.getMessage());
            Logger.saveLog();
            throw new AuraHandledException(LOGGER_NAME + ' - Error inserting installation lines: ' + e.getMessage());
        }

        processSalesOrders(newInstLines);
        
        return newInstLines;
    }
}