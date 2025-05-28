public with sharing class UpdatePackageController
{
    @AuraEnabled
    public static List<Package__c> fetchPackages(String qtId)
    {
        try
        {
            List<Package__c> packList = [SELECT Id, Name, Installation_Quantity__c, (SELECT Id, Name, Installation_Order_Status__c, Vessel_IMO__c FROM Installations__r WHERE Installation_Order_Status__c != 'Terminated') FROM Package__c WHERE Quote__c = :qtId];
            System.debug('packList --> ' + packList);
            return packList;
        }
        catch (Exception e)
        {
            throw new AuraHandledException(e.getMessage());
        }
    }
    @AuraEnabled
    public static List<Package__c> getPackageData(String packId)
    {
        try
        {
            List<Package__c> packList = [SELECT Id, Name, Installation_Quantity__c, (SELECT Id, Name, Vessel_IMO__c, Installation_Order_Status__c FROM Installations__r WHERE Installation_Order_Status__c != 'Terminated') FROM Package__c WHERE Id = :packId];
            return packList;
        }
        catch (Exception e)
        {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static string saveInstallation(String packId, String instId, String swapInstId)
    {
        try
        {
            List<Installation__c> instList = new List<Installation__c>();
            Installation__c inst = new Installation__c(
                Id = instId,
                Package__c = packId
            );
            instList.add(inst);
            if(swapInstId != NULL && swapInstId != '')
            {
                instList.add(new Installation__c(
                    Id = swapInstId,
                    Installation_Order_Status__c = 'Terminated',
                    Termination_End_Date__c = Date.today(),
                    Termination_Reason__c = 'This has been terminated on Quote-Manage Installations.'
                ));
            }
            update instList;
            return 'SUCCESS';
        }
        catch (Exception e)
        {
            throw new AuraHandledException(e.getMessage());
        }
    }
}