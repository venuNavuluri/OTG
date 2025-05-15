public class PackageTriggerHandler
{
    public static void beforeInsert(List<Package__c> newPackList)
    {
        PackageTriggerHandler.updatePackageCost(newPackList);
    }
    
    public static void updatePackageCost(List<Package__c> packList)
    {
        /*Map<String, Package__c> qlgIdPackMap = new Map<String, Package__c>();
        for(Package__c pack : packList)
        {
            qlgIdPackMap.put(pack.Quote_Line_Group__c, pack);
        }
        List<AggregateResult> arList = [SELECT Quote_Line_Group__c QuoteLineGroup, SUM(SBQQ__UnitCost__c) Cost FROM SBQQ__QuoteLine__c WHERE Quote_Line_Group__c IN :qlgIdPackMap.keySet() GROUP BY Quote_Line_Group__c];
        for(AggregateResult ar : arList)
        {
            qlgIdPackMap.get((Id)ar.get('QuoteLineGroup')).Package_Cost__c = (Decimal)ar.get('Cost');
        }*/
    }
}