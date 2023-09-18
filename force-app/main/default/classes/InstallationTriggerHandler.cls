public class InstallationTriggerHandler
{
    public static void beforeInsert(List<Installation__c> instList)
    {
        List<String> contractList = new List<String>();
        Map<String, Installation__c> contVessStatusMap = new Map<String, Installation__c>();
        Map<String, Installation__c> contOrgStatusMap = new Map<String, Installation__c>();
        for(Installation__c inst : instList)
        {
            contractList.add(inst.Contract_Customer__c);
            System.debug('vess name --> ' + inst.Vessel_Name__c);
            if(inst.Vessel_Name__c != NULL)
            {
                contVessStatusMap.put(inst.Contract_Customer__c + '-' + inst.Vessel_Name__c, inst);
            }
            else
            {
                contOrgStatusMap.put(inst.Contract_Customer__c + '-' + inst.Organisation_Name__c, inst);
            }
        }
        List<Installation__c> instRecList = [SELECT Id, Name, Contract__c, Contract_Customer__c, Organisation_Name__c, Vessel_Name__c, Installation_Order_Status__c FROM Installation__c WHERE Contract_Customer__c IN :contractList AND Installation_Order_Status__c = 'Active'];
        for(Installation__c inst : instRecList)
        {
            if(contOrgStatusMap.keySet().contains (inst.Contract_Customer__c + '-' + inst.Organisation_Name__c))
            {
                contOrgStatusMap.get(inst.Contract_Customer__c + '-' + inst.Organisation_Name__c).addError('Installation record already present, duplicate installation record not allowed.');
            }
            else if(contVessStatusMap.keySet().contains(inst.Contract_Customer__c + '-' + inst.Vessel_Name__c))
            {
                contVessStatusMap.get(inst.Contract_Customer__c + '-' + inst.Vessel_Name__c).addError('Installation record already present, duplicate installation record not allowed.');
            }
        }
    }
}