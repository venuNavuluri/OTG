public with sharing class SalesOrderFullCreditController {
    private static final String STATUS_PENDING_APPROVAL = 'Pending Approval';

    @AuraEnabled
    public static Id processFullCredit(Id salesOrderId) {
        if (salesOrderId == null) {
            throw new AuraHandledException('Sales Order Id is required.');
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Sales_Order__c sourceOrder = [
                SELECT Id, Contract__c, Installation__c, Invoice_Account__c,
                       Start_Date__c, End_Date__c, Status__c, Credit_Note__c, CurrencyIsoCode
                FROM Sales_Order__c
                WHERE Id = :salesOrderId
                LIMIT 1
            ];

            if (sourceOrder.Credit_Note__c) {
                throw new AuraHandledException('This Sales Order is already a credit note.');
            }

            List<Sales_Order_Item__c> sourceItems = [
                SELECT Id, Name, Amount__c, CurrencyIsoCode, Installation_Line__c, Subscription__c
                FROM Sales_Order_Item__c
                WHERE Sales_Order__c = :salesOrderId
            ];

            if (sourceItems.isEmpty()) {
                throw new AuraHandledException('The selected Sales Order has no Sales Order Items to credit.');
            }

            Sales_Order__c creditOrder = new Sales_Order__c(
                Contract__c = sourceOrder.Contract__c,
                Installation__c = sourceOrder.Installation__c,
                Invoice_Account__c = sourceOrder.Invoice_Account__c,
                Start_Date__c = sourceOrder.Start_Date__c,
                End_Date__c = sourceOrder.End_Date__c,
                Status__c = STATUS_PENDING_APPROVAL,
                Credit_Note__c = true,
                Original_Sales_Order__c = sourceOrder.Id,
                CurrencyIsoCode = sourceOrder.CurrencyIsoCode
            );
            insert creditOrder;

            List<Sales_Order_Item__c> creditItems = new List<Sales_Order_Item__c>();
            for (Sales_Order_Item__c sourceItem : sourceItems) {
                Decimal amount = sourceItem.Amount__c == null ? 0 : sourceItem.Amount__c;
                creditItems.add(new Sales_Order_Item__c(
                    Name = sourceItem.Name,
                    Sales_Order__c = creditOrder.Id,
                    Installation_Line__c = sourceItem.Installation_Line__c,
                    Subscription__c = sourceItem.Subscription__c,
                    CurrencyIsoCode = sourceItem.CurrencyIsoCode,
                    Amount__c = -amount.abs()
                ));
            }

            insert creditItems;
            return creditOrder.Id;
        } catch (AuraHandledException ex) {
            Database.rollback(sp);
            throw ex;
        } catch (Exception ex) {
            Database.rollback(sp);
            throw new AuraHandledException('Unable to process full credit: ' + ex.getMessage());
        }
    }
}
