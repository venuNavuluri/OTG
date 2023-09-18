public with sharing class bg_NewObjectOverrideController
{
    @AuraEnabled
    public static RecordType GetRecordTypeById(String sObjectName, String recordTypeId)
    {
        // if no record type supplied, get default record type for that object
        if (recordTypeId == null && sObjectName != null)
        {
            Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe(); 
            Schema.SObjectType sobjType = gd.get(sObjectName); 
            Schema.DescribeSObjectResult describeResult = sobjType.getDescribe(); 
            for (Schema.RecordTypeInfo rt : describeResult.getRecordTypeInfos())
            {
                if (rt.isDefaultRecordTypeMapping())
                {
                    recordTypeId = rt.getRecordTypeId();
                    break;
                }
            }
        }
        List<RecordType> recordTypes = [SELECT Id, Name, DeveloperName, SobjectType
                                        FROM RecordType 
                                        WHERE SobjectType = :sObjectName AND Id = :recordTypeId];
        if (recordTypes.isEmpty())
        {
            return null;
        }

        return recordTypes[0];
    }
}