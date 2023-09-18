public class bg_MergeVessels
{
    @InvocableMethod
    public static void MergeVessel(List<MergeVesselInput> inputs)
    {
        Map<Id, Id> masterVesselIdByDupeId = new Map<Id, Id>();
        for (MergeVesselInput input : inputs)
        {
            masterVesselIdByDupeId.put(input.duplicateVesselId, input.masterVesselId);
        }

        List<Vessel__c> vesselsToMerge = [SELECT Id, (SELECT Id, Vessel__c FROM Company_Relationships__r), 
                                                     (SELECT Id, LinkedEntityId, ContentDocumentId, ShareType FROM ContentDocumentLinks) 
                                          FROM Vessel__c 
                                          WHERE Id IN :masterVesselIdByDupeId.keySet()];
        List<SObject> objectsToUpsert = new List<SObject>();
        
        for (Vessel__c vessel : vesselsToMerge)
        {
            Id masterVesselId = masterVesselIdByDupeId.get(vessel.Id);
            for (Company_Relationship__c cr : vessel.Company_Relationships__r)
            {
                objectsToUpsert.add(new Company_Relationship__c(Id = cr.Id, Vessel__c = masterVesselId));
            }

            for (ContentDocumentLink cdl : vessel.ContentDocumentLinks)
            {
                objectsToUpsert.add(new ContentDocumentLink(LinkedEntityId = masterVesselId, ContentDocumentId = cdl.ContentDocumentId, ShareType = cdl.ShareType));
            }
        }

        upsert objectsToUpsert;
        delete vesselsToMerge;
    }

    public class MergeVesselInput
    {
        @InvocableVariable(label='Master Vessel ID' required=true)
        public String masterVesselId;
        @InvocableVariable(label='Duplicate Vessel ID' required=true)
        public Id duplicateVesselId;
    }
}