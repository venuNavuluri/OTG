public class OrderTriggerHandler
{
    public static void onBeforeInsert(List<Order> orderList)
    {
        validateInstallationCount(orderList);
    }
    
    public static void onAfterInsert(Map<Id, Order> orderMap)
    {
        updateOrderIdOnInstallation(orderMap.values());
        createContract(orderMap.keySet());
        updateSubscriptionOrderFromOpportunity(orderMap.values());
    }
    
    public static void onAfterUpdate(Map<Id, Order> oldOrderMap, List<Order> newOrderList)
    {
        List<Order> ordToCreateInst = new List<Order>();       // existing “activated” bucket
        List<Order> activatedAmendmentOrders = new List<Order>();
        List<Order> ordersToProcessBatch = new List<Order>();  // NEW: Activated + Amendment/Renewal
    
        updateSubscriptionOrderFromOpportunity(newOrderList);
    
        // Fetch details once
        Map<Id, Order> ordersWithDetails = new Map<Id, Order>([
            SELECT Id, Status, OpportunityId,
                   SBQQ__Quote__r.Auto_Termination__c,
                   SBQQ__Quote__r.Auto_Installation__c,
                   SBQQ__Quote__c,
                   SBQQ__Quote__r.SBQQ__Type__c,
                   Type
            FROM Order
            WHERE Id IN :newOrderList
        ]);
    
        // Detect status changes to Activated and categorise by Type
        for (Order ord : newOrderList) {
            Order prev = oldOrderMap.get(ord.Id);
            Order cur  = ordersWithDetails.get(ord.Id);
            if (cur == null || prev == null) continue;
    
            Boolean justActivated = (cur.Status == 'Activated' && prev.Status != 'Activated');
            if (justActivated) {
                ordToCreateInst.add(cur); // your existing flow
    
                // Batch should run ONLY for Amendment or Renewal
                if ((cur.Type == 'Amendment') && (!cur.SBQQ__Quote__r.Auto_Installation__c && !cur.SBQQ__Quote__r.Auto_Termination__c)){
                    ordersToProcessBatch.add(cur);
                }
    
                // Keep your existing Amendment-specific list for opp stage update
                if (cur.Type == 'Amendment' &&
                    cur.SBQQ__Quote__r != null &&
                    (cur.SBQQ__Quote__r.Auto_Installation__c || cur.SBQQ__Quote__r.Auto_Termination__c)) {
                    activatedAmendmentOrders.add(cur);
                }
            }
        }
    
        updatePackages(ordToCreateInst);
        updateOrderIdOnInstallation(ordToCreateInst);
        Logger.info('changepackage list 1 --> ' + ordersToProcessBatch);
        triggerChangePackageProcessing(ordersToProcessBatch);
        triggerInstallationProductUpdateBatch(ordersToProcessBatch);
        if (!activatedAmendmentOrders.isEmpty()) {
            updateOpportunityStageForActivatedAmendment(activatedAmendmentOrders);
        }
    }
    
    // New method to update Opportunity stage - Added on 07/05/2025
    @TestVisible
    private static void updateOpportunityStageForActivatedAmendment(List<Order> orders) {
        try {
            
            Set<Id> opportunityIds = new Set<Id>();
            Map<Id, Order> opportunityIdToOrderMap = new Map<Id, Order>();
            
            for (Order ord : orders) {
                if (ord.OpportunityId != null ) {
                    opportunityIds.add(ord.OpportunityId);
                    opportunityIdToOrderMap.put(ord.OpportunityId, ord);
                }
            }
            
            if (!opportunityIds.isEmpty()) {
                List<Opportunity> opportunities = [
                    SELECT Id, StageName
                    FROM Opportunity
                    WHERE Id IN :opportunityIds
                ];
                
                List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
                Map<Id, String> validationErrors = new Map<Id, String>();
                
                for (Opportunity opp : opportunities) {
                    if (opp.StageName != 'Completed') {
                        opportunitiesToUpdate.add(new Opportunity(
                            Id = opp.Id,
                            StageName = 'Completed',
                            CloseDate = System.today(),
                            Won_Reason__c = 'Other',
                            Won_Reason_Comments__c = 'Adding a vessel'
                        ));
                    } 
                }
                
                if (!opportunitiesToUpdate.isEmpty()) {
                    update(opportunitiesToUpdate);
                    System.debug('opportunitiesToUpdate---' + opportunitiesToUpdate);
                }
                
            }
        } catch (Exception ex) {
            Logger.error('Error in updateOpportunityStageForActivatedAmendment: ' + 
                         ex.getMessage() + '\n\n' + 
                         ex.getLineNumber() + '\n\n' + 
                         ex.getStackTraceString());
            Logger.saveLog();
        }
    }
    
    public static void validateInstallationCount(List<Order> orderList)
    {
        try
        {
            // Filter out orders with Type = 'Service Delivery'
            List<Order> filteredOrders = new List<Order>();
            for (Order ord : orderList) {
                if (ord.Type != 'Service Delivery') {
                    filteredOrders.add(ord);
                }
            }
            
            if (filteredOrders.isEmpty()) {
                Logger.debug('No orders to validate (all were Service Delivery). Skipping validateInstallationCount.');
                return;
            }
            
            // Map to store Quote Id and Order mapping
            Map<Id, Order> qtIdOrderMap = new Map<Id, Order>();
            for (Order ord : filteredOrders) {
                qtIdOrderMap.put(ord.SBQQ__Quote__c, ord);
            }
            
            // Query the Package records
            List<Package__c> packList = [
                SELECT 
                Id, 
                Name, 
                Quote__c, 
                Quote__r.Auto_Installation__c, 
                Quote__r.Auto_Termination__c, 
                Quote_Line_Group__r.Installation_Quantity__c,
                Installation_Quantity__c, 
                (SELECT Id FROM Installations__r WHERE Installation_Order_Status__c != 'Terminated') 
                FROM Package__c 
                WHERE 
                Quote__c IN :qtIdOrderMap.keySet() 
                AND Contract__r.Migrated_Contract__c != TRUE 
                ORDER BY CreatedDate DESC
            ];
            
            // Validate installation counts
            for (Package__c pack : packList)
            {
                Integer activeInstallations = pack.Installations__r != null ? pack.Installations__r.size() : 0;
                
                Logger.debug('Package: ' + pack.Name + 
                             ', Installation Quantity: ' + pack.Quote_Line_Group__r.Installation_Quantity__c + 
                             ', Active Installations: ' + activeInstallations);
                
                if (!pack.Quote__r.Auto_Installation__c && !pack.Quote__r.Auto_Termination__c)
                {
                    if (pack.Quote_Line_Group__r.Installation_Quantity__c != activeInstallations )
                    {
                        qtIdOrderMap.get(pack.Quote__c).addError(
                            'The number of active installations on the package must match the Installation Quantity on the package. ' +
                            'Package: ' + pack.Name + ', Installation Quantity: ' + pack.Quote_Line_Group__r.Installation_Quantity__c +
                            ', Active Installations: ' + activeInstallations
                        );
                    }
                }
            }
        }
        catch (Exception ex)
        {
            Logger.error('Error in validateInstallationCount: ' + ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
        }
    }
    
    @future
    public static void createContract(Set<Id> orderIdSet) {
        if (orderIdSet == null || orderIdSet.isEmpty()) return;

        try {
            List<Order> orderList = [SELECT Id, Name, SBQQ__Quote__c FROM Order WHERE Id IN :orderIdSet];
            if (orderList.isEmpty()) return;

            Set<Id> qtIdList = new Set<Id>();
            for (Order ord : orderList) {
                if (ord.SBQQ__Quote__c != null) qtIdList.add(ord.SBQQ__Quote__c);
            }
            if (qtIdList.isEmpty()) return;

            Map<Id, SBQQ__Quote__c> qtMap = new Map<Id, SBQQ__Quote__c>([
                SELECT Id, Name, SBQQ__BillingFrequency__c, SBQQ__SubscriptionTerm__c, SBQQ__Type__c, Auto_Installation__c, Auto_Termination__c, SBQQ__StartDate__c, SBQQ__EndDate__c 
                FROM SBQQ__Quote__c 
                WHERE Id IN :qtIdList
            ]);

            List<Order> ordUpdateList = new List<Order>();
            for (Order ord : orderList) {
                SBQQ__Quote__c q = qtMap.get(ord.SBQQ__Quote__c);
                if (q == null) continue;

                Order upd = new Order(Id = ord.Id);
                upd.Billing_Frequency__c = q.SBQQ__BillingFrequency__c;

                if (q.Auto_Termination__c || q.SBQQ__Type__c == 'Renewal') {
                    upd.SBQQ__RenewalTerm__c = q.SBQQ__SubscriptionTerm__c;
                    upd.Status = 'Activated';
                    upd.SBQQ__Contracted__c = true;
                    ordUpdateList.add(upd);
                } else if (q.Auto_Installation__c || q.SBQQ__Type__c == 'Amendment' || q.SBQQ__Type__c == 'Quote') {
                    upd.Status = 'Pending Implementation';
                    ordUpdateList.add(upd);
                }
            }
            if (!ordUpdateList.isEmpty()) {
                update ordUpdateList;
            }
        } catch (Exception ex) {
            Logger.error(ex.getMessage());
            Logger.saveLog();
        }
    }
    
    public static void updateOrderIdOnInstallation(List<Order> orderList) {
    if (orderList == null || orderList.isEmpty()) return;

            try {
                // Map QuoteId -> Order (last one wins per Quote in this txn)
                Map<Id, Order> quoteIdToOrder = new Map<Id, Order>();
                Set<Id> renewalQuoteIds    = new Set<Id>();
                Set<Id> nonRenewalQuoteIds = new Set<Id>();
        
                for (Order ord : orderList) {
                    if (ord.SBQQ__Quote__c == null) continue;
                    quoteIdToOrder.put(ord.SBQQ__Quote__c, ord);
        
                    if (ord.Type == 'Renewal') {
                        renewalQuoteIds.add(ord.SBQQ__Quote__c);
                    } else {
                        nonRenewalQuoteIds.add(ord.SBQQ__Quote__c);
                    }
                }
                if (quoteIdToOrder.isEmpty()) return;
        
                List<Installation__c> toUpdate = new List<Installation__c>();
        
                // ---------- PATH A: RENEWAL ----------
                if (!renewalQuoteIds.isEmpty()) {
                    
                    List<Package__c> renewalPkgs = [
                        SELECT Id, Temp_Quote__c, Quote__c, Quote_Line_Group__c
                        FROM Package__c
                        WHERE Temp_Quote__c IN :renewalQuoteIds
                    ];
                    if (!renewalPkgs.isEmpty()) {
                        // Group for easy access
                        Map<Id, Package__c> pkgById = new Map<Id, Package__c>();
                        Map<Id, Id> pkgToTempQuote  = new Map<Id, Id>();
                        for (Package__c p : renewalPkgs) {
                            pkgById.put(p.Id, p);
                            if (p.Temp_Quote__c != null) {
                                pkgToTempQuote.put(p.Id, p.Temp_Quote__c);
                            }
                        }
        
                        // 2) Fetch installations under those packages
                        List<Installation__c> insts = [
                            SELECT Id, Package__c, Quote__c, Quote_Line_Group__c,
                                   Order__c, Installation_Order_Status__c
                            FROM Installation__c
                            WHERE Package__c IN :pkgById.keySet()
                        ];
        
                        // 3) Update installations that currently belong to the temp quote
                        for (Installation__c inst : insts) {
                            Package__c pkg = pkgById.get(inst.Package__c);
                        
                            Order relatedOrder = quoteIdToOrder.get(pkg.Temp_Quote__c);
                        
                            Installation__c upd = new Installation__c(
                                Id                  = inst.Id,
                                Order__c            = relatedOrder.Id,
                                Quote__c            = relatedOrder.SBQQ__Quote__c,
                                Quote_Line_Group__c = pkg.Quote_Line_Group__c,
                                Package__c          = pkg.Id
                            );
                            // If the current Installation is still in Draft, move it to Pending Implementation
                                if (inst.Installation_Order_Status__c == 'Draft') {
                                    upd.Installation_Order_Status__c = 'Pending Implementation';
                                }
                            toUpdate.add(upd);
                        }
                    }
                }
        
                // ---------- PATH B: NON-RENEWAL ----------
                if (!nonRenewalQuoteIds.isEmpty()) {
                    Map<Id, SBQQ__Quote__c> quotes = new Map<Id, SBQQ__Quote__c>([
                        SELECT Id,
                               (SELECT Id, Order__c, Installation_Order_Status__c FROM Installations__r)
                        FROM SBQQ__Quote__c
                        WHERE Id IN :nonRenewalQuoteIds
                    ]);
        
                    for (SBQQ__Quote__c q : quotes.values()) {
                        Order ord = quoteIdToOrder.get(q.Id);
                        if (ord == null || q.Installations__r == null) continue;
        
                        for (Installation__c inst : q.Installations__r) {
                            Installation__c upd = new Installation__c(
                                Id = inst.Id,
                                Order__c = ord.Id
                            );
                            if (inst.Installation_Order_Status__c == 'Draft') {
                                upd.Installation_Order_Status__c = 'Pending Implementation';
                            }
                            toUpdate.add(upd);
                        }
                    }
                }
        
                if (!toUpdate.isEmpty()) {
                    update toUpdate;
                }
            } catch (Exception ex) {
                Logger.error('updateOrderIdOnInstallation failed: ' + ex.getMessage()
                    + ' | line: ' + ex.getLineNumber() + ' | stack: ' + ex.getStackTraceString());
                Logger.saveLog();
            }
        }
    
    public static void updatePackages(List<Order> ordList) {
        if (ordList == null || ordList.isEmpty()) return;

        Set<Id> qtIdList = new Set<Id>();
        Map<Id, Order> quoteIdToOrder = new Map<Id, Order>();
        for (Order ord : ordList) {
            if (ord != null && ord.SBQQ__Quote__c != null && ord.Type != 'Service Delivery' ) {
                qtIdList.add(ord.SBQQ__Quote__c);
                quoteIdToOrder.put(ord.SBQQ__Quote__c, ord);
            }
        }
        if (qtIdList.isEmpty()) return;
        
        List<SBQQ__QuoteLineGroup__c> qlgList = [
            SELECT Id, Name, SBQQ__Quote__c, SBQQ__Quote__r.SBQQ__Type__c, SBQQ__Quote__r.Auto_Installation__c, SBQQ__Quote__r.Auto_Termination__c, 
                   Installation_Quantity__c, Installation_Price__c, Products__c, Package__c, Installation_Change_Type__c,InstallationChangeType__c, Prior_Installation_Quantity__c, Product_Change_Type__c 
            FROM SBQQ__QuoteLineGroup__c 
            WHERE SBQQ__Quote__c IN :qtIdList
        ];
        if (qlgList.isEmpty()) return;

        Map<Id, Package__c> packMap = new Map<Id, Package__c>([
            SELECT Id, Name, CurrencyIsoCode, Quote_Line_Group__c, Installation_Quantity__c, Installation_Change_Type__c, InstallationCost__c, Prior_Installation_Quantity__c, Products__c, Temp_Quote_Line_Group__c, Quote__c
            FROM Package__c 
            WHERE Temp_Quote_Line_Group__c IN :new Map<Id, SBQQ__QuoteLineGroup__c>(qlgList).keySet()
        ]);
        List<Package__c> packListToUpdate = new List<Package__c>();
        
        for (SBQQ__QuoteLineGroup__c qlg : qlgList) {
            Package__c pack = packMap.get(qlg.Package__c);
            if (pack == null) continue;

            Boolean autoInstall = (qlg.SBQQ__Quote__r != null && qlg.SBQQ__Quote__r.Auto_Installation__c == true);
            Boolean autoTerminate = (qlg.SBQQ__Quote__r != null && qlg.SBQQ__Quote__r.Auto_Termination__c == true);

            if (!autoInstall || !autoTerminate) {
                pack.InstallationCost__c = qlg.Installation_Price__c;
                pack.Name = qlg.Name;
                pack.Products__c = qlg.Products__c; 
                pack.Product_Change_Type__c = qlg.Product_Change_Type__c;
            }
            pack.Installation_Quantity__c = qlg.Installation_Quantity__c;
            pack.Installation_Change_Type__c = qlg.InstallationChangeType__c;
            pack.Prior_Installation_Quantity__c = qlg.Prior_Installation_Quantity__c;
            pack.Quote__c = qlg.SBQQ__Quote__c;
            pack.Order__c = quoteIdToOrder.get(qlg.SBQQ__Quote__c).Id;
            pack.Quote_Line_Group__c = qlg.Id;
            packListToUpdate.add(pack);
        }
        
        if (!packListToUpdate.isEmpty()) {
            update packListToUpdate;
            createPackageActions(packListToUpdate, quoteIdToOrder);
        }
    }
    
    // Revert: synchronous helper as originally present
    private static void createPackageActions(List<Package__c> updatedPacks, Map<Id, Order> quoteIdToOrder) {
        if (updatedPacks == null || updatedPacks.isEmpty()) return;

        List<Package_Action__c> actions = new List<Package_Action__c>();

        for (Package__c pack : updatedPacks) {
            Order ord = quoteIdToOrder.get(pack.Quote__c);

            Package_Action__c act = new Package_Action__c();
            act.Action_Date__c           = Date.today();
            act.Installation_Quantity__c = (Integer)pack.Installation_Quantity__c;
            act.Installation_Cost__c     = pack.InstallationCost__c;
            act.Package__c               = pack.Id;
            act.Quote__c                 = pack.Quote__c;
            act.Quote_Line_Group__c      = pack.Quote_Line_Group__c;
            act.CurrencyIsoCode          = pack.CurrencyIsoCode;
            act.Package_Name__c          = pack.Name;
            if (ord != null) {
                act.Order__c       = ord.Id;
                act.Opportunity__c = ord.OpportunityId;
                act.Type__c        = ord.Type;
            }
            actions.add(act);
        }

        if (!actions.isEmpty()) {
            insert actions;
        }
    }
       
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getOpportunityId(Id orderId) {
        if (orderId == null) {
            return new Map<String, Object>();
        }
        Order order = [SELECT OpportunityId, Type FROM Order WHERE Id = :orderId LIMIT 1];
        return new Map<String, Object>{
            'opportunityId' => order.OpportunityId,
            'orderType'     => order.Type
        };
    }
    
    @AuraEnabled
    public static void updateOrderAsAdmin(Id orderId, String newStatus) {
        if (orderId == null || String.isBlank(newStatus)) return;

        System.runAs(getAdminUser()) {
            Order ord = [SELECT Id, Status FROM Order WHERE Id = :orderId LIMIT 1];
            ord.Status = newStatus;
            update ord;
            System.debug('Updated Order Status -- ' + newStatus + ' Order Id: ' + ord.Id);
        }
    }
    
    private static User getAdminUser() {
        return [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = true LIMIT 1];
    }
    
    public static void updateSubscriptionOrderFromOpportunity(List<Order> orders) {
        try {         
            if (orders == null || orders.isEmpty()) {
                System.debug('Orders list is null or empty');
                return;
            }
            
            // Filter only Service Delivery orders with an Opportunity
            List<Order> serviceDeliveryOrders = new List<Order>();
            Set<Id> opportunityIds = new Set<Id>();
            for (Order ord : orders) {
                System.debug('Service Delivery Order Id: ' + ord.Id + ', Type: ' + ord.Type + ', OpportunityId: ' + ord.OpportunityId);
                if (ord.Type == 'Service Delivery' && ord.OpportunityId != null) {
                    serviceDeliveryOrders.add(ord);
                    opportunityIds.add(ord.OpportunityId);
                    System.debug('Added to serviceDeliveryOrders. Current size: ' + serviceDeliveryOrders.size());
                }
            }
            
            if (serviceDeliveryOrders.isEmpty()) {
                System.debug('No Service Delivery orders found.');
                return; // nothing to process
            }
            
            Map<Id, Order> latestActivatedNewOrderMap = new Map<Id, Order>();
            List<Order> relatedOrders = [
                SELECT Id, OpportunityId, CreatedDate
                FROM Order
                WHERE OpportunityId IN :opportunityIds
                AND Type != 'Service Delivery' ORDER BY CreatedDate DESC
                
            ];
            System.debug('Related Activated "New": ' + relatedOrders.size());
            
            for (Order relOrd : relatedOrders) {
                if (!latestActivatedNewOrderMap.containsKey(relOrd.OpportunityId)) {
                    latestActivatedNewOrderMap.put(relOrd.OpportunityId, relOrd);
                    System.debug('Added latest Activated "New" order for Opp Id: ' + relOrd.OpportunityId + ' -> Order Id: ' + relOrd.Id);
                }
            }
            
            // Prepare updates
            List<Order> ordersToUpdate = new List<Order>();
            for (Order serviceOrder : serviceDeliveryOrders) {
                Order latestOrder = latestActivatedNewOrderMap.get(serviceOrder.OpportunityId);
                System.debug('Service Order Id: ' + serviceOrder.Id + ', Latest Activated "New" Order Id: ' + (latestOrder != null ? latestOrder.Id : 'NULL'));
                if (latestOrder != null && serviceOrder.Subscription_Order__c != latestOrder.Id) {
                    ordersToUpdate.add(new Order(
                        Id = serviceOrder.Id,
                        Subscription_Order__c = latestOrder.Id
                    ));
                    System.debug('Service Order for update: ' + serviceOrder.Id  + ' -> Subscription_Order__c = ' + latestOrder.Id);
                }
            }
            
            if (!ordersToUpdate.isEmpty()) {
                update ordersToUpdate;
                System.debug(' Updating Service Delivery orders. ' + ordersToUpdate);
                
            } else {
                System.debug(' No Service Delivery orders require update.');
            }
            
        } catch (Exception ex) {
            Logger.error('Error in updateSubscriptionOrderFromOpportunity: ' + ex.getMessage() + '\n' +ex.getLineNumber() + '\n' + ex.getStackTraceString());
            Logger.saveLog();
        }
    }
    
    private static void triggerChangePackageProcessing(List<Order> orders) {
        if (orders == null || orders.isEmpty()) return;
    
        Set<Id> orderIds = new Set<Id>();
        for (Order o : orders) if (o != null && o.Id != null) orderIds.add(o.Id);
        if (orderIds.isEmpty()) return;

        Integer matchCount = [
            SELECT COUNT()
            FROM Installation__c
            WHERE Order__c IN :orderIds
              AND Change_Package_Status__c = 'In Progress'
              AND Installation_Order_Status__c = 'Active'
        ];
    
        if (matchCount > 0) {
            String jobName = 'ChangePackageInstallations' + String.valueOf(System.currentTimeMillis());
            System.scheduleBatch(new ChangePackageInstallationsBatch(orderIds), jobName, 3, 1);
        }
    }
    
    // Method to execute InstallationProductUpdateBatch if related packages have Product_Change_Type__c != 'New Package' AND Product_Change_Type__c != null and count > 0
    private static void triggerInstallationProductUpdateBatch(List<Order> orders) {
        if (orders == null || orders.isEmpty()) return;
    
        Set<Id> orderIds = new Set<Id>();
        Set<Id> quoteIds = new Set<Id>();
        for (Order o : orders) {
            if (o == null) continue;
            if (o.Id != null) {
                orderIds.add(o.Id);
            }
            if (o.SBQQ__Quote__c != null) {
                quoteIds.add(o.SBQQ__Quote__c);
            }
        }
        if (orderIds.isEmpty()) return;

        // Check if packages meet the criteria
        Boolean shouldProcess = shouldProcessChangePackage(quoteIds);
        
        if (shouldProcess) {
            String jobName = 'InstallationProductUpdate_' + String.valueOf(System.currentTimeMillis());
            System.scheduleBatch(new InstallationProductUpdateBatch(orderIds), jobName, 2, 1);
        }
    }
    
    // Method to check if related packages have Product_Change_Type__c != 'New Package' AND Product_Change_Type__c != null and count > 0
    private static Boolean shouldProcessChangePackage(Set<Id> quoteIds) {
        if (quoteIds == null || quoteIds.isEmpty()) {
            return false;
        }

        // Count packages that meet the criteria
        Integer matchCount = [
            SELECT COUNT()
            FROM Package__c
            WHERE Quote__c IN :quoteIds
              AND Product_Change_Type__c != 'New Package'
              AND Product_Change_Type__c != null
        ];

        return matchCount > 0;
    }
    
}