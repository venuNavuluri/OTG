public class SubscriptionTriggerHandler extends TriggerHandler
{
    public override void beforeInsert()
    {
    }
    public override void afterInsert()
    {
        SubscriptionTriggerHandler.updateInstallationLine((Map<Id, SBQQ__Subscription__c>)Trigger.newMap);
    }
    protected override void afterDelete()
    {   
    }
    
    public override void beforeUpdate()
    {
    }
    
    public override void afterUpdate()
    {
    }
    
    public static void updateInstallationLine(Map<Id, SBQQ__Subscription__c> newSubMap)
    {
        Map<Id, SBQQ__Subscription__c> qlIdSubMap = new Map<Id, SBQQ__Subscription__c>();
        for(SBQQ__Subscription__c sub : newSubMap.values())
        {
            qlIdSubMap.put(sub.SBQQ__QuoteLine__c, sub);
        }
        List<Installation_Line__c> instLineList = [SELECT Id, Name, Quote_Line__c, Start_Date__c, End_Date__c, Net_Total__c FROM Installation_Line__c WHERE Quote_Line__c IN :qlIdSubMap.keySet()];
        for(Installation_Line__c instLine : instLineList)
        {
            instLine.Subscription__c = qlIdSubMap.get(instLine.Quote_Line__c).Id;
            instLine.Start_Date__c = qlIdSubMap.get(instLine.Quote_Line__c).SBQQ__SegmentStartDate__c;
            instLine.End_Date__c = qlIdSubMap.get(instLine.Quote_Line__c).SBQQ__SegmentEndDate__c;
            instLine.Net_Total__c = qlIdSubMap.get(instLine.Quote_Line__c).SBQQ__NetPrice__c;
        }
        if(!instLineList.isEmpty())
        {
            update instLineList;
        }
    }
}