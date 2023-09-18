public class bg_ClearDuplicateBypass
{
    @InvocableMethod
    public static void ClearDuplicateBypass(List<ClearDuplicateInput> inputs)
    {
        Map<Id, SObject> objectsToUpdate = new Map<Id, SObject>();
        for (ClearDuplicateInput input : inputs)
        {
            sObject obj = input.recordId.getSObjectType().newSObject(input.recordId);
            obj.put('Id', input.recordId);
            obj.put('Bypass_Duplicate_Rule__c', false);
            objectsToUpdate.put(obj.Id, obj);
        }
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.allowSave = true;
        dml.DuplicateRuleHeader.runAsCurrentUser = true; 
        List<Database.SaveResult> saveResults = Database.update(objectsToUpdate.values(), dml);

    }

    public class ClearDuplicateInput
    {
        @InvocableVariable(label='Object Name' required=true)
        public String objectName;
        @InvocableVariable(label='Record Id' required=true)
        public Id recordId;
    }
}