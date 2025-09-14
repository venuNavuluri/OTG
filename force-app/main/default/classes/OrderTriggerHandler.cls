public class OrderTriggerHandler
{
    public static void onBeforeInsert(List<Order> orderList)
    {
        validateInstallationCount(orderList);
    }
    
    public static void onAfterInsert(Map<Id, Order> orderMap)
    {
        //updateOrderIdOnInstallation(orderMap.values());
        createContract(orderMap.keySet());
        updateSubscriptionOrderFromOpportunity(orderMap.values());
    }
    
    public static void onAfterUpdate(Map<Id, Order> oldOrderMap, List<Order> newOrderList)
    {
        List<Order> ordToCreateInst = new List<Order>();
        List<Order> activatedAmendmentOrders = new List<Order>(); // Added on 07/05/2025
        
        updateSubscriptionOrderFromOpportunity(newOrderList);
        
        // Query additional fields we need for processing
        Map<Id, Order> ordersWithDetails = new Map<Id, Order>([
            SELECT Id, Status, OpportunityId, SBQQ__Quote__c, SBQQ__Quote__r.SBQQ__Type__c, SBQQ__Quote__r.Auto_Installation__c, SBQQ__Quote__r.Auto_Termination__c, Type
            FROM Order
            WHERE Id IN :newOrderList
        ]);
        
        for(Order ord : newOrderList)
        {
            Order currentOrder = ordersWithDetails.get(ord.Id);
            
            if(ord.Status == 'Activated' && (ord.Status != oldOrderMap.get(ord.Id).Status) && ord.Type != 'Service Delivery')
            {
                ordToCreateInst.add(ord);
                
            }
        }
        System.debug('ordToCreateInst --> ' + ordToCreateInst);
        updateOrderIdOnInstallation(ordToCreateInst);
        
        for(Order ord : newOrderList) {
            Order currentOrder = ordersWithDetails.get(ord.Id);
            
            // Check for status change to Activated and Amendment type
            if(currentOrder.Type == 'Amendment' &&
               currentOrder.SBQQ__Quote__r != null && (currentOrder.SBQQ__Quote__r.Auto_Installation__c||currentOrder.SBQQ__Quote__r.Auto_Termination__c)) {
                   
                   activatedAmendmentOrders.add(currentOrder);
               }
        }
        
        // Update Opportunity stage for activated Amendment orders - Added on 07/05/2025
        if(!activatedAmendmentOrders.isEmpty()) {
            updateOpportunityStageForActivatedAmendment(activatedAmendmentOrders);
        }
    }
    
    // New method to update Opportunity stage - Added on 07/05/2025
    private static void updateOpportunityStageForActivatedAmendment(List<Order> orders) {
        try {
            Set<Id> opportunityIds = new Set<Id>();
            Map<Id, Order> opportunityIdToOrderMap = new Map<Id, Order>();
            
            for (Order ord : orders) {
                if (ord.OpportunityId != null) {
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
                            CloseDate = System.today()
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
                             ', Installation Quantity: ' + pack.Installation_Quantity__c + 
                             ', Active Installations: ' + activeInstallations);
                
                if (!pack.Quote__r.Auto_Installation__c && !pack.Quote__r.Auto_Termination__c)
                {
                    if (pack.Installation_Quantity__c != activeInstallations )
                    {
                        qtIdOrderMap.get(pack.Quote__c).addError(
                            'The number of active installations on the package must match the Installation Quantity on the package. ' +
                            'Package: ' + pack.Name + ', Installation Quantity: ' + pack.Installation_Quantity__c +
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
    public static void createContract(Set<Id> orderIdSet)
    {
        try
        {
            List<Order> orderList = [SELECT Id, Name, SBQQ__Quote__c FROM Order WHERE Id IN :orderIdSet];
            List<Id> qtIdList = new List<Id>();
            for(Order ord : orderList)
            {
                qtIdList.add(ord.SBQQ__Quote__c);
            }
            Map<Id, SBQQ__Quote__c> qtMap = new Map<Id, SBQQ__Quote__c>([SELECT Id, Name, SBQQ__BillingFrequency__c, SBQQ__SubscriptionTerm__c, SBQQ__Type__c, Auto_Installation__c, Auto_Termination__c, SBQQ__StartDate__c, SBQQ__EndDate__c FROM SBQQ__Quote__c WHERE Id IN :qtIdList]);
            List<Order> ordUpdateList = new List<Order>();
            for(Order ord : orderList)
            {
                ord.Billing_Frequency__c = qtMap.get(ord.SBQQ__Quote__c).SBQQ__BillingFrequency__c;
                if(qtMap.get(ord.SBQQ__Quote__c).Auto_Termination__c || qtMap.get(ord.SBQQ__Quote__c).SBQQ__Type__c == 'Renewal')//need to add renewal logic
                {
                    //ord.EffectiveDate = qtMap.get(ord.SBQQ__Quote__c).SBQQ__StartDate__c;
                    //ord.EndDate	 = qtMap.get(ord.SBQQ__Quote__c).SBQQ__EndDate__c;
                    ord.SBQQ__RenewalTerm__c = qtMap.get(ord.SBQQ__Quote__c).SBQQ__SubscriptionTerm__c;
                    ord.Status = 'Activated';
                    ord.SBQQ__Contracted__c = TRUE;
                    ordUpdateList.add(ord);
                }
                else if(qtMap.get(ord.SBQQ__Quote__c).Auto_Installation__c || qtMap.get(ord.SBQQ__Quote__c).SBQQ__Type__c == 'Amendment' || qtMap.get(ord.SBQQ__Quote__c).SBQQ__Type__c == 'Quote')
                {
                    ord.Status = 'Pending Implementation';
                    ordUpdateList.add(ord);
                }
            }
            System.debug('ordList --> ' + ordUpdateList);
            if(!ordUpdateList.isEmpty())
            {
                update ordUpdateList;
            }
        }
        catch(Exception ex)
        {
            Logger.error(ex.getMessage());
            Logger.saveLog();
        }
    }
    
    public static void updateOrderIdOnInstallation(List<Order> orderList)
    {
        try
        {
            Map<Id, Order> qtIdOrdMap = new Map<Id, Order>();
            for(Order ord : orderList)
            {
                qtIdOrdMap.put(ord.SBQQ__Quote__c, ord);
            }
            List<Installation__c> instList = new List<Installation__c>();
            Map<Id, SBQQ__Quote__c> qtMap = new Map<Id, SBQQ__Quote__c>([SELECT Id, Name, Installation__c, SBQQ__Type__c, SBQQ__MasterContract__c, SBQQ__MasterContract__r.StartDate, SBQQ__MasterContract__r.EndDate, (SELECT Id, Name, Order__c, Installation_Order_Status__c FROM Installations__r) FROM SBQQ__Quote__c WHERE Id IN :qtIdOrdMap.keySet()]);
            if(!qtMap.isEmpty())
            {
                for(Order ord : orderList)
                {   
                    
                    for(Installation__c inst : qtMap.get(ord.SBQQ__Quote__c).Installations__r)
                    {
                        If(inst.Installation_Order_Status__c == 'Draft'){
                            inst.Installation_Order_Status__c = 'Pending Implementation'; 
                        }
                        inst.Order__c = ord.Id;
                        instList.add(inst);
                    }
                    
                }
            }
            if(instList != NULL && !instList.isEmpty())
            {
                update instList;
            }
        }
        catch(Exception ex)
        {
            Logger.error(ex.getMessage());
            Logger.saveLog();
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getOpportunityId(Id orderId) {
        Order order = [SELECT OpportunityId, Type FROM Order WHERE Id = :orderId LIMIT 1];
        return new Map<String, Object>{
            'opportunityId' => order.OpportunityId,
                'orderType' => order.Type
                };
                    }
    
    @AuraEnabled
    public static void updateOrderAsAdmin(Id orderId, String newStatus) {
        // Run in system context without sharing
        System.runAs(getAdminUser()) {
            Order ord = [SELECT Id, Status FROM Order WHERE Id = :orderId];
            ord.Status = newStatus;
            update ord;
            system.debug('Updated Order Status --'+ newStatus + 'Order Id:' + ord );
        }
    }
    
    private static User getAdminUser() {
        return [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = true LIMIT 1];
    }
    
    public static void updateSubscriptionOrderFromOpportunity(List<Order> orders) {
        try {         
            if (orders == null || orders.isEmpty()) {
                return;
            }
            
            // Filter only Service Delivery orders with an Opportunity
            List<Order> serviceDeliveryOrders = new List<Order>();
            Set<Id> opportunityIds = new Set<Id>();
            for (Order ord : orders) {
                if (ord.Type == 'Service Delivery' && ord.OpportunityId != null) {
                    serviceDeliveryOrders.add(ord);
                    opportunityIds.add(ord.OpportunityId);
                }
            }
            
            if (serviceDeliveryOrders.isEmpty()) {
                return;
            }
            
            Map<Id, Order> latestActivatedNewOrderMap = new Map<Id, Order>();
            List<Order> relatedOrders = [
                SELECT Id, OpportunityId, CreatedDate
                FROM Order
                WHERE OpportunityId IN :opportunityIds
                AND Type != 'Service Delivery' ORDER BY CreatedDate DESC
                
            ];
            
            for (Order relOrd : relatedOrders) {
                if (!latestActivatedNewOrderMap.containsKey(relOrd.OpportunityId)) {
                    latestActivatedNewOrderMap.put(relOrd.OpportunityId, relOrd);
                }
            }
            
            // Prepare updates
            List<Order> ordersToUpdate = new List<Order>();
            for (Order serviceOrder : serviceDeliveryOrders) {
                Order latestOrder = latestActivatedNewOrderMap.get(serviceOrder.OpportunityId);
                if (latestOrder != null && serviceOrder.Subscription_Order__c != latestOrder.Id) {
                    ordersToUpdate.add(new Order(
                        Id = serviceOrder.Id,
                        Subscription_Order__c = latestOrder.Id
                    ));
                }
            }
            
            if (!ordersToUpdate.isEmpty()) {
                update ordersToUpdate;
            } else {
            }
            
        } catch (Exception ex) {
            Logger.error('Error in updateSubscriptionOrderFromOpportunity: ' + ex.getMessage() + '\n' +ex.getLineNumber() + '\n' + ex.getStackTraceString());
            Logger.saveLog();
        }
    }
}