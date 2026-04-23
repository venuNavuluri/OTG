public with sharing class SalesOrderCloneController {
    private static final String STATUS_PENDING_APPROVAL = 'Pending Approval';

    @AuraEnabled
    public static Id cloneSalesOrder(Id salesOrderId) {
        if (salesOrderId == null) {
            throw new AuraHandledException('Sales Order Id is required.');
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Sales_Order__c sourceOrder = [
                SELECT Id, Contract__c, Installation__c, Invoice_Account__c,
                       Start_Date__c, End_Date__c, Comments__c, CurrencyIsoCode
                FROM Sales_Order__c
                WHERE Id = :salesOrderId
                LIMIT 1
            ];

            List<Sales_Order_Item__c> sourceItems = [
                SELECT Id, Name, Amount__c, CurrencyIsoCode, Installation_Line__c, Subscription__c
                FROM Sales_Order_Item__c
                WHERE Sales_Order__c = :salesOrderId
            ];

            Sales_Order__c clonedOrder = new Sales_Order__c(
                Contract__c = sourceOrder.Contract__c,
                Installation__c = sourceOrder.Installation__c,
                Invoice_Account__c = sourceOrder.Invoice_Account__c,
                Start_Date__c = sourceOrder.Start_Date__c,
                End_Date__c = sourceOrder.End_Date__c,
                Comments__c = sourceOrder.Comments__c,
                Status__c = STATUS_PENDING_APPROVAL,
                Credit_Note__c = false,
                Original_Sales_Order__c = sourceOrder.Id,
                CurrencyIsoCode = sourceOrder.CurrencyIsoCode
            );
            insert clonedOrder;

            if (!sourceItems.isEmpty()) {
                List<Sales_Order_Item__c> clonedItems = new List<Sales_Order_Item__c>();
                for (Sales_Order_Item__c sourceItem : sourceItems) {
                    clonedItems.add(new Sales_Order_Item__c(
                        Name = sourceItem.Name,
                        Sales_Order__c = clonedOrder.Id,
                        Installation_Line__c = sourceItem.Installation_Line__c,
                        Subscription__c = sourceItem.Subscription__c,
                        CurrencyIsoCode = sourceItem.CurrencyIsoCode,
                        Amount__c = sourceItem.Amount__c
                    ));
                }
                insert clonedItems;
            }

            return clonedOrder.Id;
        } catch (AuraHandledException ex) {
            Database.rollback(sp);
            throw ex;
        } catch (Exception ex) {
            Database.rollback(sp);
            throw new AuraHandledException('Unable to clone sales order: ' + ex.getMessage());
        }
    }
}