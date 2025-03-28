public class QuoteTriggerHelper
{
    public static void updateQlgCheckbox(List<SBQQ__Quote__c> newQuoteList)
    {
        try
        {
            for(SBQQ__Quote__c qt : newQuoteList)
            {
                qt.SBQQ__LineItemsGrouped__c = TRUE;
                qt.Renewal_Calculate__c = (qt.SBQQ__Type__c == 'Renewal');
            }
        }
        catch(Exception ex)
        {
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
        }
    }
    
    public static void createDummyQLG(Map<Id, SBQQ__Quote__c> newQuoteMap)
    {
        try
        {
            List<SBQQ__QuoteLineGroup__c> qlgList = new List<SBQQ__QuoteLineGroup__c>();
            for(SBQQ__Quote__c qt : newQuoteMap.values())
            {
                if(qt.SBQQ__Type__c == 'Quote')
                {
                    qlgList.add(new SBQQ__QuoteLineGroup__c(
                        SBQQ__Quote__c = qt.Id,
                        Name = 'Package 1',
                        SBQQ__Number__c = 1,
                        SBQQ__ListTotal__c = 0,
                        SBQQ__CustomerTotal__c = 0,
                        SBQQ__NetTotal__c = 0
                    ));
                }
            }
            if(!qlgList.isEmpty())
            {
                insert qlgList;
            }
        }
        catch(Exception ex)
        {
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
        }
    }
    
    public static void validateInstallationCount(Map<Id, SBQQ__Quote__c> newQuoteMap, Map<Id, SBQQ__Quote__c> oldQuoteMap)
    {
        try
        {
            System.debug('Ids --> ' + newQuoteMap.keySet());
            List<SBQQ__QuoteLineGroup__c> qlgList = [SELECT Id, Name, Package__c, SBQQ__Quote__c FROM SBQQ__QuoteLineGroup__c WHERE SBQQ__Quote__c IN :newQuoteMap.keySet() AND SBQQ__Quote__r.Auto_Installation__c = FALSE AND SBQQ__Quote__r.Auto_Termination__c = FALSE];
            Map<Id, Id> packIdqtIdMap = new Map<Id, Id>();
            for(SBQQ__QuoteLineGroup__c qlg : qlgList)
            {
                packIdQtIdMap.put(qlg.Package__c, qlg.SBQQ__Quote__c);
            }
            List<AggregateResult> arList = [SELECT Package__c Package, COUNT(ID) TotalCount FROM Installation__c WHERE Package__c IN :packIdQtIdMap.keySet() AND Installation_Order_Status__c != 'Terminated' GROUP BY Package__c];
            System.debug('arList --> ' + arList);
            Map<Id, Integer> qtIdInstCountMap = new Map<Id, Integer>();
            if(!arList.isEmpty())
            {
                for(AggregateResult ar : arList)
                {
                    SBQQ__Quote__c qt = newQuoteMap.get(packIdQtIdMap.get((Id)ar.get('Package')));
                    System.debug('ar --> ' + ar);
                    if(qtIdInstCountMap.get(qt.Id) == NULL)
                    {
                        qtIdInstCountMap.put(qt.Id, 0);
                    }
                    Integer count = qtIdInstCountMap.get(qt.Id) + (Integer)ar.get('TotalCount');
                    qtIdInstCountMap.put(qt.Id, count);
                }
                for(SBQQ__Quote__c qt : newQuoteMap.values())
                {
                    System.debug('inst count 1 --> ' + qtIdInstCountMap.get(qt.Id));
                    System.debug('inst count 2 --> ' + qt.Total_Installations__c);
                    
                    if(qt.SBQQ__Ordered__c && !oldQuoteMap.get(qt.Id).SBQQ__Ordered__c && qtIdInstCountMap.get(qt.Id) < qt.Total_Installations__c)
                    {
                        System.debug('qtId --> ' + qt.Id);
                        qt.addError('Please add all the installations before marking the Quote as Ordered');
                    }
                }
            }
            else
            {
                for(SBQQ__Quote__c qt : newQuoteMap.values())
                {
                    if(!qt.Auto_Installation__c && !qt.Auto_Termination__c && qt.SBQQ__Ordered__c && qt.SBQQ__Ordered__c && !oldQuoteMap.get(qt.Id).SBQQ__Ordered__c)
                    {
                        qt.addError('Please add all the installations before marking the Quote as Ordered');
                    }
                }
            }
        }
        catch(Exception ex)
        {
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
        }
    }

}