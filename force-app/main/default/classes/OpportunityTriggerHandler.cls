public with sharing class OpportunityTriggerHandler {
    // Re-entrancy guard
    private static Boolean isExecuting = false;
    
    // Entry points per context
    public static void beforeInsert(List<Opportunity> newList) {
        if (start()) {
            try {
                // Add your before insert logic here
                // Example: defaulting fields or validation
                // validateCloseDate(newList);
                manageCreatedBySalesUser(newList);
                setOpportunityTypes(newList, null);
                applyAmendedContractSelection(newList, null);
                updateOpportunityNames(newList, null);
            } finally { stop(); }
        }
    }
    
    public static void beforeUpdate(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        if (start()) {
            try {
                // Add your before update logic here
                // Example: prevent stage regression, normalize data
                // normalizeFields(newList);
                setOpportunityTypes(newList, oldMap);
                applyAmendedContractSelection(newList, oldMap);
                updateOpportunityNames(newList, oldMap);
            } finally { stop(); }
        }
    }
    
    public static void beforeDelete(List<Opportunity> oldList) {
        if (start()) {
            try {
                // Add your before delete logic here
            } finally { stop(); }
        }
    }
    
    public static void afterInsert(List<Opportunity> newList) {
        if (start()) {
            try {
                // Add your after insert logic here
                // Example: enqueue async jobs, create related records
                syncOpportunityNames(newList);
            } finally { stop(); }
        }
    }
    
    public static void afterUpdate(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        if (start()) {
            try {
                // Update Account_Subscription_Annual_Order_Value__c on related Account
                // when SBQQ__AmendedContract__c changes and the amended contract Name is the target value.
                updateOpportunityAnnualValueFromContract(newList, oldMap);
                updateAmendedContractIfTerminated(newList, oldMap);
                // Keep placeholder for other after update logic
                // handleStageChanges(newList, oldMap);
            } finally { stop(); }
        }
    }
    
    public static void afterDelete(List<Opportunity> oldList) {
        if (start()) {
            try {
                // Add your after delete logic here
            } finally { stop(); }
        }
    }
    
    public static void afterUndelete(List<Opportunity> newList) {
        if (start()) {
            try {
                // Add your after undelete logic here
            } finally { stop(); }
        }
    }
    
    // Common guard helpers
    private static Boolean start() {
        if (isExecuting) return false;
        isExecuting = true;
        return true;
    }
    private static void stop() {
        isExecuting = false;
    }

    private static void updateOpportunityNames(List<Opportunity> opportunities, Map<Id, Opportunity> oldOpportunityMap) {
        if (opportunities == null || opportunities.isEmpty()) {
            return;
        }

        List<Opportunity> opportunitiesToName = new List<Opportunity>();
        for (Opportunity opp : opportunities) {
            Opportunity oldOpp = oldOpportunityMap == null ? null : oldOpportunityMap.get(opp.Id);
            if (shouldCalculateOpportunityName(opp, oldOpp)) {
                opportunitiesToName.add(opp);
            }
        }

        if (!opportunitiesToName.isEmpty()) {
            applyOpportunityNames(opportunitiesToName);
        }
    }

    private static Boolean shouldCalculateOpportunityName(Opportunity newOpp, Opportunity oldOpp) {
        if (newOpp == null || newOpp.AccountId == null) {
            return false;
        }
        if (oldOpp == null) {
            return true;
        }

        return newOpp.Name != oldOpp.Name ||
            newOpp.Account_Name__c != oldOpp.Account_Name__c ||
            newOpp.Customer_Status__c != oldOpp.Customer_Status__c ||
            newOpp.Existing_Opportunity_Type__c != oldOpp.Existing_Opportunity_Type__c ||
            newOpp.AccountId != oldOpp.AccountId ||
            newOpp.Account_Customer_Status__c != oldOpp.Account_Customer_Status__c ||
            newOpp.Business_Unit__c != oldOpp.Business_Unit__c;
    }

    private static void syncOpportunityNames(List<Opportunity> opportunities) {
        if (opportunities == null || opportunities.isEmpty()) {
            return;
        }

        Set<Id> opportunityIds = new Set<Id>();
        for (Opportunity opp : opportunities) {
            if (opp.Id != null) {
                opportunityIds.add(opp.Id);
            }
        }
        if (opportunityIds.isEmpty()) {
            return;
        }

        List<Opportunity> opportunitiesForNames = [
            SELECT Id, AccountId, Name, Account_Customer_Status__c,
                Existing_Opportunity_Type__c, Business_Unit__c, CreatedDate
            FROM Opportunity
            WHERE Id IN :opportunityIds
        ];

        Map<Id, String> originalNamesById = new Map<Id, String>();
        for (Opportunity opp : opportunitiesForNames) {
            originalNamesById.put(opp.Id, opp.Name);
        }

        applyOpportunityNames(opportunitiesForNames);

        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
        for (Opportunity opp : opportunitiesForNames) {
            if (opp.Name != originalNamesById.get(opp.Id)) {
                opportunitiesToUpdate.add(new Opportunity(
                    Id = opp.Id,
                    Name = opp.Name
                ));
            }
        }

        if (!opportunitiesToUpdate.isEmpty()) {
            update opportunitiesToUpdate;
        }
    }

    private static void applyOpportunityNames(List<Opportunity> opportunities) {
        if (opportunities == null || opportunities.isEmpty()) {
            return;
        }

        Set<Id> accountIds = new Set<Id>();
        for (Opportunity opp : opportunities) {
            if (opp.AccountId != null) {
                accountIds.add(opp.AccountId);
            }
        }
        if (accountIds.isEmpty()) {
            return;
        }

        Map<Id, Account> accountsById = new Map<Id, Account>([
            SELECT Id, Name, Customer_Status__c
            FROM Account
            WHERE Id IN :accountIds
        ]);

        for (Opportunity opp : opportunities) {
            Account accountRec = accountsById.get(opp.AccountId);
            if (accountRec != null) {
                opp.Name = buildOpportunityName(opp, accountRec);
            }
        }
    }

    private static String buildOpportunityName(Opportunity opp, Account accountRec) {
        String customerStatus = opp.Account_Customer_Status__c != null
            ? calculateAccountStatus(opp.Account_Customer_Status__c)
            : calculateAccountStatus(accountRec.Customer_Status__c);
        String existingOppType = opp.Existing_Opportunity_Type__c != null ? opp.Existing_Opportunity_Type__c : '';
        Datetime opportunityDate = opp.CreatedDate != null ? opp.CreatedDate : Datetime.now();
        String businessUnit = opp.Business_Unit__c != null ? getBusinessUnitShortName(opp.Business_Unit__c) : '';

        return businessUnit + '/ ' + customerStatus + '/ ' + existingOppType + '/ ' +
            accountRec.Name.left(50) + '/ ' + opportunityDate.format('yyyy-MM-dd');
    }

    private static String calculateAccountStatus(String customerStatus) {
        if (customerStatus == 'Prospect' || customerStatus == 'Lost' || customerStatus == 'Lapsed') {
            return 'New Customer';
        }
        if (customerStatus == 'Active') {
            return 'Existing Customer';
        }
        return '';
    }

    private static String getBusinessUnitShortName(String businessUnit) {
        if (businessUnit == null) {
            return '';
        }

        switch on businessUnit {
            when 'Voyage Performance & Optimization' { return 'VPO'; }
            when 'Voyage Management' { return 'VMS'; }
            when 'HCM Crew' { return 'HCM Crew'; }
            when 'HCM Learning, Assessment and Competency' { return 'HCM LAC'; }
            when 'Technical Ship Management' { return 'TSM'; }
            when 'Governance, Risk & Compliance' { return 'GRC'; }
            when 'Cloud Fleet Manager' { return 'CFM'; }
            when 'API' { return 'API'; }
            when else { return businessUnit; }
        }
    }

    public static void applyAmendedContractSelection(List<Opportunity> opportunities, Map<Id, Opportunity> oldOpportunityMap) {
        if (opportunities == null || opportunities.isEmpty()) {
            return;
        }

        Set<Id> contractIds = new Set<Id>();
        for (Opportunity opp : opportunities) {
            Opportunity oldOpp = oldOpportunityMap == null ? null : oldOpportunityMap.get(opp.Id);
            if (shouldApplyAmendedContractSelection(opp, oldOpp)) {
                contractIds.add(opp.Amend_Contract_Sales__c);
            }
        }
        if (contractIds.isEmpty()) {
            return;
        }

        Map<Id, Contract> contractsById = new Map<Id, Contract>([
            SELECT Id, Subscription_Value__c, CurrencyIsoCode
            FROM Contract
            WHERE Id IN :contractIds
        ]);

        for (Opportunity opp : opportunities) {
            Contract relatedContract = contractsById.get(opp.Amend_Contract_Sales__c);
            if (relatedContract == null) {
                continue;
            }

            opp.SBQQ__AmendedContract__c = relatedContract.Id;
            opp.Account_Subscription_Annual_Order_Value__c = relatedContract.Subscription_Value__c;
            opp.CurrencyIsoCode = relatedContract.CurrencyIsoCode;
        }
    }

    private static Boolean shouldApplyAmendedContractSelection(Opportunity newOpp, Opportunity oldOpp) {
        if (newOpp == null || newOpp.Amend_Contract_Sales__c == null) {
            return false;
        }
        return oldOpp == null || newOpp.Amend_Contract_Sales__c != oldOpp.Amend_Contract_Sales__c;
    }
    
    // ===== Main implementation for updating Opportunity annual value from amended contract =====
    @TestVisible
    private static void updateOpportunityAnnualValueFromContract(List<Opportunity> newOpportunities, Map<Id, Opportunity> oldOpportunityMap) {
        if (newOpportunities == null || newOpportunities.isEmpty()) {
            return;
        }
        
        Map<Id, Opportunity> newOpportunityMap = new Map<Id, Opportunity>(newOpportunities);
        Map<Id, Opportunity> oldOpportunityMapSafe = (oldOpportunityMap == null)
            ? new Map<Id, Opportunity>()
            : oldOpportunityMap;
        
        Set<Id> targetContractIds = new Set<Id>();
        Map<Id, Id> oppIdToContractId = new Map<Id, Id>();
        
        for (Opportunity newOpp : newOpportunities) {
            Opportunity oldOpp = oldOpportunityMapSafe.get(newOpp.Id);
            
            if (newOpp.Business_Unit__c != 'HCM Learning, Assessment and Competency') {
                continue;
            }
            
            if (!String.isBlank(newOpp.StageName) && newOpp.StageName.equalsIgnoreCase('Closed Won')) {
                continue;
            }
            
            Id targetContractId = newOpp.SBQQ__AmendedContract__c;
            
            if (targetContractId == null && 'Renewal'.equalsIgnoreCase(newOpp.Existing_Opportunity_Type__c)) {
                targetContractId = newOpp.SBQQ__RenewedContract__c;
            }
            
            if (targetContractId == null) {
                continue;
            }
            
            targetContractIds.add(targetContractId);
            oppIdToContractId.put(newOpp.Id, targetContractId);
        }
        
        if (targetContractIds.isEmpty()) {
            return;
        }
        
        Map<Id, Contract> contractsById = new Map<Id, Contract>([
            SELECT Id, Subscription_Value__c
            FROM Contract
            WHERE Id IN :targetContractIds
        ]);
        
        if (contractsById.isEmpty()) {
            return;
        }
        
        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
        for (Id oppId : oppIdToContractId.keySet()) {
            Opportunity newOpp = newOpportunityMap.get(oppId);
            Id contractId = oppIdToContractId.get(oppId);
            
            if (!contractsById.containsKey(contractId)) {
                continue;
            }
            
            Contract relatedContract = contractsById.get(contractId);
            
            if (relatedContract == null) {
                continue;
            }
            
            Decimal newContractValue = relatedContract.Subscription_Value__c;
            
            if (newContractValue == null) {
                continue;
            }
            
            Decimal currentValue = newOpp.Account_Subscription_Annual_Order_Value__c;
            
            if (currentValue == newContractValue) {
                continue;
            }
            
            Opportunity recordToUpdate = new Opportunity(
                Id = oppId,
                Account_Subscription_Annual_Order_Value__c = newContractValue
            );
            opportunitiesToUpdate.add(recordToUpdate);
        }
        
        if (!opportunitiesToUpdate.isEmpty()) {
            update opportunitiesToUpdate;
        }
    }
    private static void manageCreatedBySalesUser(List<Opportunity> newOpportunities)
    {
        Id userRoleId = UserInfo.getUserRoleId();
        
        if (userRoleId != null)
        {
            UserRole r = [select Id, Name from UserRole where Id = :userRoleId];
            
            for (Opportunity opp : newOpportunities)
            {
                if (r.Name.contains('Sales') && r.Name != 'Sales Ops' && r.Name != 'Non Sales')
                {
                    opp.Created_By_Sales_User__c = 'Yes';
                }
            }
        }
    }

    private static List<Opportunity> setOpportunityTypes(List<Opportunity> opportunities, Map<Id, Opportunity> oldOpportunityMap) {
        List<Opportunity> classifiedOpportunities = new List<Opportunity>();
        if (opportunities == null || opportunities.isEmpty()) {
            return classifiedOpportunities;
        }

        Set<Id> accountIds = new Set<Id>();
        Set<Id> productSolutionIds = new Set<Id>();
        Set<String> productSolutionKeys = new Set<String>();
        for (Opportunity opp : opportunities) {
            if (!shouldCalculateOpportunityType(opp, oldOpportunityMap == null ? null : oldOpportunityMap.get(opp.Id))) {
                continue;
            }
            if (opp.AccountId != null) {
                accountIds.add(opp.AccountId);
            }
            if (opp.AccountId != null && !String.isBlank(opp.Business_Unit__c)) {
                productSolutionKeys.add(buildProductSolutionKey(opp.AccountId, opp.Business_Unit__c));
            }
            if (opp.Product_Solutions__c != null) {
                productSolutionIds.add(opp.Product_Solutions__c);
            }
        }

        if (accountIds.isEmpty()) {
            return classifiedOpportunities;
        }

        Map<Id, Account> accountsById = new Map<Id, Account>([
            SELECT Id, Customer_Status__c
            FROM Account
            WHERE Id IN :accountIds
        ]);

        Map<Id, Product_Solutions__c> productSolutionsById = new Map<Id, Product_Solutions__c>();
        if (!productSolutionIds.isEmpty()) {
            productSolutionsById = new Map<Id, Product_Solutions__c>([
                SELECT Id, Account_ID__c, Product_Solution__c, Product_Area_Status__c
                FROM Product_Solutions__c
                WHERE Id IN :productSolutionIds
            ]);
        }

        Map<String, Product_Solutions__c> productSolutionsByAccountAndBusinessUnit = new Map<String, Product_Solutions__c>();
        if (!productSolutionKeys.isEmpty()) {
            for (Product_Solutions__c productSolution : [
                SELECT Id, Account_ID__c, Product_Solution__c, Product_Area_Status__c
                FROM Product_Solutions__c
                WHERE Account_ID__c IN :accountIds
                  AND Product_Solution__c != null
            ]) {
                String key = buildProductSolutionKey(productSolution.Account_ID__c, productSolution.Product_Solution__c);
                if (productSolutionKeys.contains(key)) {
                    Product_Solutions__c existingProductSolution = productSolutionsByAccountAndBusinessUnit.get(key);
                    if (existingProductSolution == null ||
                        (existingProductSolution.Product_Area_Status__c != 'Active' &&
                         productSolution.Product_Area_Status__c == 'Active')) {
                        productSolutionsByAccountAndBusinessUnit.put(key, productSolution);
                    }
                }
            }
        }

        for (Opportunity opp : opportunities) {
            Opportunity oldOpp = oldOpportunityMap == null ? null : oldOpportunityMap.get(opp.Id);
            if (!shouldCalculateOpportunityType(opp, oldOpp)) {
                continue;
            }

            Account accountRec = accountsById.get(opp.AccountId);
            Product_Solutions__c currentProductSolution = opp.Product_Solutions__c == null
                ? null
                : productSolutionsById.get(opp.Product_Solutions__c);
            Product_Solutions__c matchedProductSolution = productSolutionsByAccountAndBusinessUnit.get(
                buildProductSolutionKey(opp.AccountId, opp.Business_Unit__c)
            );
            Product_Solutions__c productSolution = shouldReplaceProductSolution(opp, currentProductSolution, matchedProductSolution)
                ? matchedProductSolution
                : currentProductSolution;

            if (productSolution != null && opp.Product_Solutions__c != productSolution.Id) {
                opp.Product_Solutions__c = productSolution.Id;
            }
            if (accountRec != null) {
                opp.Customer_Status_List__c = accountRec.Customer_Status__c;
            }
            if (productSolution != null) {
                opp.Account_Customer_Status__c = productSolution.Product_Area_Status__c;
            }

            OpportunityTypeResult result = calculateOpportunityType(opp, accountRec, productSolution);
            if (result == null) {
                continue;
            }
            opp.Existing_Opportunity_Type__c = result.opportunityType;
            opp.Contract_Type__c = result.contractType;
            classifiedOpportunities.add(opp);
        }

        return classifiedOpportunities;
    }

    private static Boolean shouldReplaceProductSolution(
        Opportunity opp,
        Product_Solutions__c currentProductSolution,
        Product_Solutions__c matchedProductSolution
    ) {
        if (matchedProductSolution == null) {
            return false;
        }
        if (currentProductSolution == null) {
            return true;
        }
        if (currentProductSolution.Account_ID__c != opp.AccountId ||
            currentProductSolution.Product_Solution__c != opp.Business_Unit__c) {
            return true;
        }
        return currentProductSolution.Product_Area_Status__c != 'Active' &&
            matchedProductSolution.Product_Area_Status__c == 'Active';
    }

    private static Boolean shouldCalculateOpportunityType(Opportunity newOpp, Opportunity oldOpp) {
        if (newOpp == null || newOpp.AccountId == null) {
            return false;
        }
        if (newOpp.Existing_Opportunity_Type__c == 'Renewal' ||
            newOpp.Existing_Opportunity_Type__c == 'Account Growth' ||
            newOpp.Existing_Opportunity_Type__c == 'OLP Transition') {
            return false;
        }
        if (oldOpp == null) {
            return true;
        }
        return newOpp.Sales_Type__c != oldOpp.Sales_Type__c ||
            newOpp.AccountId != oldOpp.AccountId ||
            newOpp.Business_Unit__c != oldOpp.Business_Unit__c ||
            newOpp.Product_Group__c != oldOpp.Product_Group__c ||
            newOpp.Product_Solutions__c != oldOpp.Product_Solutions__c ||
            newOpp.Account_Customer_Status__c != oldOpp.Account_Customer_Status__c ||
            newOpp.Existing_Opportunity_Type__c != oldOpp.Existing_Opportunity_Type__c;
    }

    private static OpportunityTypeResult calculateOpportunityType(
        Opportunity opp,
        Account accountRec,
        Product_Solutions__c productSolution
    ) {
        if (opp.Sales_Type__c == 'One-Time' || opp.Sales_Type__c == 'Service') {
            return new OpportunityTypeResult('One-Time', null);
        }

        if (opp.Sales_Type__c != 'Subscription' || accountRec == null) {
            return null;
        }

        Boolean accountActive = accountRec.Customer_Status__c == 'Active';
        Boolean productAreaActive = productSolution != null && productSolution.Product_Area_Status__c == 'Active';

        if (accountActive && productAreaActive) {
            return new OpportunityTypeResult('Up-sell', 'Existing Contract');
        }
        if (accountActive) {
            return new OpportunityTypeResult('Cross-sell', 'New Contract');
        }
        return new OpportunityTypeResult('Whitespace', 'New Contract');
    }

    private static String buildProductSolutionKey(Id accountId, String businessUnit) {
        return String.valueOf(accountId) + '|' + String.valueOf(businessUnit);
    }

    private class OpportunityTypeResult {
        String opportunityType;
        String contractType;

        OpportunityTypeResult(String opportunityType, String contractType) {
            this.opportunityType = opportunityType;
            this.contractType = contractType;
        }
    }
    
    // ===== implementation for updating Opportunity Amended Contract and Renew Contract value from contract - Next Contract =====
    @TestVisible
    private static void updateAmendedContractIfTerminated(
        List<Opportunity> newOpportunities,
        Map<Id, Opportunity> oldOpportunityMap
    ) {
        try {
            
            if (newOpportunities == null || newOpportunities.isEmpty()) {
                return;
            }
            
            Set<Id> contractIds = new Set<Id>();
            
            Map<Id, Id> oppToAmendedContract = new Map<Id, Id>();
            Map<Id, Id> oppToRenewedContract = new Map<Id, Id>();
            
            for (Opportunity newOpp : newOpportunities) {
                
                // Skip closed opportunities
                if (
                    newOpp.StageName == 'Closed Won' ||
                    newOpp.StageName == 'Closed Lost' ||
                    newOpp.StageName == 'Completed'
                ) {
                    continue;
                }
                
                // Amended Contract
                if (newOpp.SBQQ__AmendedContract__c != null) {
                    contractIds.add(newOpp.SBQQ__AmendedContract__c);
                    oppToAmendedContract.put(newOpp.Id, newOpp.SBQQ__AmendedContract__c);
                }
                
                // Renewed Contract
                if (newOpp.SBQQ__RenewedContract__c != null) {
                    contractIds.add(newOpp.SBQQ__RenewedContract__c);
                    oppToRenewedContract.put(newOpp.Id, newOpp.SBQQ__RenewedContract__c);
                }
            }
            
            if (contractIds.isEmpty()) {
                return;
            }
            
            Map<Id, Contract> contractMap = new Map<Id, Contract>([
                SELECT Id, Status, Next_Contract__c
                FROM Contract
                WHERE Id IN :contractIds
            ]);
            
            List<Opportunity> oppsToUpdate = new List<Opportunity>();
            
            // Amended Contract logic
            for (Id oppId : oppToAmendedContract.keySet()) {
                Contract cont = contractMap.get(oppToAmendedContract.get(oppId));
                if (cont != null && cont.Status == 'Terminated' && cont.Next_Contract__c != null) {oppsToUpdate.add(new Opportunity(Id = oppId, SBQQ__AmendedContract__c = cont.Next_Contract__c));
                }
            }
            
            // Renewed Contract logic
            for (Id oppId : oppToRenewedContract.keySet()) {
                Contract cont = contractMap.get(oppToRenewedContract.get(oppId));
                if (cont != null && cont.Status == 'Terminated' && cont.Next_Contract__c != null) {oppsToUpdate.add(new Opportunity(Id = oppId,SBQQ__RenewedContract__c = cont.Next_Contract__c));
                }
            }
            
            if (!oppsToUpdate.isEmpty()) { update oppsToUpdate;
            }
            
        } catch (Exception e) {
            System.debug('Message: ' + e.getMessage());
            System.debug('Line: ' + e.getLineNumber());
            System.debug('StackTrace: ' + e.getStackTraceString());
            
            // Re-throw so transaction behaves correctly (important for triggers)
            throw e;
        }
    }    
}
