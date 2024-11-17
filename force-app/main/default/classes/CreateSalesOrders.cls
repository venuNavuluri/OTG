public class CreateSalesOrders
{
    @AuraEnabled
    public static String createSORecords(Id conId)
    {
        try
        {
            List<Sales_Order__c> soList = [SELECT Id, Name FROM Sales_Order__c WHERE Contract__c = :conId];
            if(soList != NULL && !soList.isEmpty())
            {
                delete soList;
            }
            List<Installation_Line__c> existingInstLineList = [SELECT Id, Name FROM Installation_Line__c WHERE Installation__r.Contract__c = :conId];
            if(existingInstLineList != NULL && !existingInstLineList.isEmpty())
            {
                delete existingInstLineList;
            }
            List<SBQQ__Subscription__c> subList = [SELECT Id, Name, SBQQ__Product__c,SBQQ__Product__r.Name, SBQQ__Contract__c, SBQQ__Contract__r.CurrencyIsoCode, Package__c, SBQQ__Contract__r.Billing_Frequency__c, SBQQ__Contract__r.ContractTerm, SBQQ__Contract__r.Migrated_Contract__c, SBQQ__StartDate__c, SBQQ__EndDate__c, SBQQ__Quantity__c, SBQQ__NetPrice__c,CurrencyIsoCode FROM SBQQ__Subscription__c WHERE SBQQ__Contract__c = :conId];
            System.debug('subList --> ' + subList);
            Map<Id, List<SBQQ__Subscription__c>> packIdSubsListMap = new Map<Id, List<SBQQ__Subscription__c>>();
            for(SBQQ__Subscription__c sub : subList)
            {
                if(packIdSubsListMap.get(sub.Package__c) == NULL)
                {
                    packIdSubsListMap.put(sub.Package__c, new List<SBQQ__Subscription__c>());
                }
                packIdSubsListMap.get(sub.Package__c).add(sub);
            }
            List<Package__c> packList = [SELECT Id, Name FROM Package__c WHERE Id IN :packIdSubsListMap.keySet()];
            List<Installation__c> instList = [SELECT Id, Name, Package__c FROM Installation__c WHERE Package__c IN :packIdSubsListMap.keySet() AND Contract__c = :conId AND Installation_Order_Status__c = 'Active' AND Package__c != NULL];
            Map<Id, List<Installation__c>> packIdInstListMap = new Map<Id, List<Installation__c>>();
            for(Installation__c inst : instList)
            {
                if(packIdInstListMap.get(inst.Package__c) == NULL)
                {
                    packIdInstListMap.put(inst.Package__c, new List<Installation__c>());
                }
                packIdInstListMap.get(inst.Package__c).add(inst);
            }
            List<Installation_Line__c> instLineList = new List<Installation_Line__c>();
            for(SBQQ__Subscription__c sub : subList)
            {
                if(packIdInstListMap.get(sub.Package__c) != NULL)
                {
                    for(Installation__c inst : packIdInstListMap.get(sub.Package__c))
                    {
                    
                        Installation_Line__c instLine = new Installation_Line__c();
                        instLine.Installation__c = inst.Id;
                        instLine.Name = sub.SBQQ__Product__r.Name;
                        instLine.Product__c = sub.SBQQ__Product__c;
                        instLine.Net_Total__c = sub.SBQQ__NetPrice__c;
                        instLine.CurrencyIsoCode = sub.SBQQ__Contract__r.CurrencyIsoCode;
                        instLine.Subscription__c = sub.Id;
                        instLine.Start_Date__c = sub.SBQQ__StartDate__c;
                        instLine.End_Date__c = sub.SBQQ__EndDate__c;
                        instLineList.add(instLine);
                        
                    }
                }
            }
            if(!instLineList.isEmpty())
            {
                System.debug('instLineList --> ' + instLineList);
                insert instLineList;
            }
            List<Installation__c> installations = [
                SELECT Id, Name, Quote__c, Contract__c, Contract__r.Billing_Frequency__c, 
                Contract__r.ContractTerm, Contract__r.StartDate, Contract__r.EndDate, 
                Installation_Start_date__c, Installation_End_date__c, 
                Invoice_Account__c, CurrencyIsoCode 
                FROM Installation__c 
                WHERE Contract__c = :conId AND Installation_Order_Status__c = 'Active'
            ];
            CreateSalesOrderService.createSORecords(installations);
            //CreateSalesOrderService.createSOIRecords(installations);
            Contract cont = new Contract(
                Id = conId,
                Sales_Orders_Created__c = TRUE
            );
            update cont;
            return 'SUCCESS';
        }
        catch(Exception ex)
        {
            System.debug('Exception --> ' + ex);
            System.debug('Exception Line --> ' + ex.getLineNumber());
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            return 'ERROR' + ex.getMessage() + ' - ' + ex.getLineNumber();
        }
    }
}