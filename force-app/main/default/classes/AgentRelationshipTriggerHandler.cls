public class AgentRelationshipTriggerHandler {
    private static Boolean isExecuting = false;
    public static void handleBeforeInsert(List<Agent_Relationship__c> newRecords) {
        if (isExecuting) return; 
        isExecuting = true;
        
        List<Agent_Relationship__c> recordsToUpdate = new List<Agent_Relationship__c>();
        
        try {
            Set<Id> b2bAccountIds = new Set<Id>();
            for (Agent_Relationship__c record : newRecords) {
                if (record.B2B_Account__c != null) {
                    b2bAccountIds.add(record.B2B_Account__c);
                }
            }
            
            List<Agent_Relationship__c> existingRecords = [
                SELECT Id, B2B_Account__c, Agent_Account__c, Business_Unit__c
                FROM Agent_Relationship__c
                WHERE B2B_Account__c IN :b2bAccountIds
            ];
            
            Map<String, Agent_Relationship__c> existingRecordMap = new Map<String, Agent_Relationship__c>();
            for (Agent_Relationship__c existingRecord : existingRecords) {
                String key = existingRecord.B2B_Account__c + '-' + existingRecord.Agent_Account__c;
                existingRecordMap.put(key, existingRecord);
            }
            
            for (Agent_Relationship__c newRecord : newRecords) {
                String key = newRecord.B2B_Account__c + '-' + newRecord.Agent_Account__c;
                if (existingRecordMap.containsKey(key)) {
                    Agent_Relationship__c existingRecord = existingRecordMap.get(key);
                    
                    List<String> existingUnits = existingRecord.Business_Unit__c != null
                        ? new List<String>(existingRecord.Business_Unit__c.split(';'))
                        : new List<String>();
                    List<String> newUnits = newRecord.Business_Unit__c != null
                        ? new List<String>(newRecord.Business_Unit__c.split(';'))
                        : new List<String>();
                    
                    Boolean conflict = false;
                    for (String newUnit : newUnits) {
                        if (existingUnits.contains(newUnit)) {
                            conflict = true;
                            break;
                        }
                    }
                    
                    if (conflict) {
                        newRecord.addError(
                            'Business Unit value already exists for the same B2B Account and Agent Account.'
                        );
                    } else {
                        Set<String> mergedUnits = new Set<String>(existingUnits);
                        mergedUnits.addAll(newUnits);
                        existingRecord.Business_Unit__c = String.join(new List<String>(mergedUnits), ';');
                        recordsToUpdate.add(existingRecord);
                    }
                }
                for (Agent_Relationship__c existingRecord : existingRecords) {
                    if (existingRecord.B2B_Account__c == newRecord.B2B_Account__c 
                        && existingRecord.Agent_Account__c != newRecord.Agent_Account__c) {
                            
                            List<String> existingUnits = existingRecord.Business_Unit__c != null
                                ? new List<String>(existingRecord.Business_Unit__c.split(';'))
                                : new List<String>();
                            
                            List<String> newUnits = newRecord.Business_Unit__c != null
                                ? new List<String>(newRecord.Business_Unit__c.split(';'))
                                : new List<String>();
                            
                            for (String newUnit : newUnits) {
                                if (existingUnits.contains(newUnit)) {
                                    newRecord.addError(
                                        'Business Unit is already associated with another Agent Account for this B2B Account.'
                                    );
                                    break;
                                }
                            }
                        }
                }
            }
            
            if (!recordsToUpdate.isEmpty()) {
                update recordsToUpdate;
            }
            
        } catch (Exception ex) {
            throw ex;
        } finally {
            isExecuting = false; 
        }
    }    
    public static void handleBeforeUpdate(List<Agent_Relationship__c> newRecords, Map<Id, Agent_Relationship__c> oldMap) {
        if (isExecuting) return; 
        isExecuting = true;
        List<Agent_Relationship__c> recordsToUpdate = new List<Agent_Relationship__c>();
        
        try {
            Set<Id> b2bAccountIds = new Set<Id>();
            for (Agent_Relationship__c record : newRecords) {
                if (record.B2B_Account__c != null) {
                    b2bAccountIds.add(record.B2B_Account__c);
                }
            }
            List<Agent_Relationship__c> existingRecords = [
                SELECT Id, B2B_Account__c, Agent_Account__c, Business_Unit__c
                FROM Agent_Relationship__c
                WHERE B2B_Account__c IN :b2bAccountIds
            ];
            
            Map<String, Agent_Relationship__c> existingRecordMap = new Map<String, Agent_Relationship__c>();
            for (Agent_Relationship__c existingRecord : existingRecords) {
                String key = existingRecord.B2B_Account__c + '-' + existingRecord.Agent_Account__c;
                existingRecordMap.put(key, existingRecord);
            }
            
            for (Agent_Relationship__c newRecord : newRecords) {
                String key = newRecord.B2B_Account__c + '-' + newRecord.Agent_Account__c;
                
                if (existingRecordMap.containsKey(key)) {
                    Agent_Relationship__c existingRecord = existingRecordMap.get(key);
                    
                    List<String> existingUnits = existingRecord.Business_Unit__c != null
                        ? new List<String>(existingRecord.Business_Unit__c.split(';'))
                        : new List<String>();
                    List<String> newUnits = newRecord.Business_Unit__c != null
                        ? new List<String>(newRecord.Business_Unit__c.split(';'))
                        : new List<String>();
                    
                    Boolean conflict = false;
                    for (String newUnit : newUnits) {
                        if (existingUnits.contains(newUnit)) {
                            conflict = true;
                            break;
                        }
                    }
                    
                    if (conflict) {
                        newRecord.addError(
                            'Business Unit value already exists for the same B2B Account and Agent Account.'
                        );
                    } else {
                        Set<String> mergedUnits = new Set<String>(existingUnits);
                        mergedUnits.addAll(newUnits);
                        existingRecord.Business_Unit__c = String.join(new List<String>(mergedUnits), ';');
                        recordsToUpdate.add(existingRecord);
                    }
                }
            }
            
            if (!recordsToUpdate.isEmpty()) {
                update recordsToUpdate;
            }
            
        } catch (Exception ex) {
            throw ex;
        } finally {
            isExecuting = false;
        }
    }
    
    public static void handleAfterInsert(List<Agent_Relationship__c> newRecords) {
        List<Id> recordsToDelete = new List<Id>();
        Set<Id> newRecordIds = new Set<Id>();
        Set<Id> b2bAccountIds = new Set<Id>(); 
        Set<String> newRecordKeys = new Set<String>();
        
        for (Agent_Relationship__c newRecord : newRecords) {
            if (newRecord.B2B_Account__c != null) {
                b2bAccountIds.add(newRecord.B2B_Account__c);
            }
            newRecordIds.add(newRecord.Id);
            String key = newRecord.B2B_Account__c + '-' + newRecord.Agent_Account__c + '-' + newRecord.Business_Unit__c;
            newRecordKeys.add(key);
        }
        
        List<Agent_Relationship__c> existingRecords = [
            SELECT Id, B2B_Account__c, Agent_Account__c, Business_Unit__c
            FROM Agent_Relationship__c
            WHERE B2B_Account__c IN :b2bAccountIds
            AND Id NOT IN :newRecordIds 
        ];
        
        for (Agent_Relationship__c newRecord : newRecords) {
            String newBusinessUnit = newRecord.Business_Unit__c;
            for (Agent_Relationship__c existingRecord : existingRecords) {
                if (existingRecord.B2B_Account__c == newRecord.B2B_Account__c && existingRecord.Agent_Account__c == newRecord.Agent_Account__c) {
                    if (existingRecord.Business_Unit__c != null && existingRecord.Business_Unit__c.contains(newBusinessUnit)) {
                        recordsToDelete.add(newRecord.Id);
                    } else {
                        
                    }
                }
            }
        }
        if (!recordsToDelete.isEmpty()) {
            deleteAsync(recordsToDelete);
        } else {
            
        }
    }
    
    @future
    public static void deleteAsync(List<Id> recordIds) {
        
        List<Agent_Relationship__c> recordsToDelete = [SELECT Id, Name FROM Agent_Relationship__c WHERE Id IN :recordIds];
        delete recordsToDelete;
        
    }  
}