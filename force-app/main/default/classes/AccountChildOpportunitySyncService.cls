public with sharing class AccountChildOpportunitySyncService {
    public static final String BYPASS_KEY = 'FLOW:Update_Account_Child_Opps';

    private static final Set<String> FLEET_BUSINESS_UNITS = new Set<String>{
        'Fleet',
        'Technical Ship Management'
    };
    private static final Set<String> CREW_BUSINESS_UNITS = new Set<String>{
        'Crew',
        'HCM Crew'
    };
    private static final Set<String> LEARNING_BUSINESS_UNITS = new Set<String>{
        'Learning & Assessment',
        'HCM Learning, Assessment and Competency'
    };
    private static final Set<String> MARINE_BUSINESS_UNITS = new Set<String>{
        'Marine Regulations',
        'Governance, Risk & Compliance'
    };

    private static Set<Id> queuedAccountIds = new Set<Id>();

    public static void afterAccountUpdate(List<Account> newAccounts, Map<Id, Account> oldAccountMap) {
        if (AutomationBypass.bypassFlows(BYPASS_KEY) || newAccounts == null || newAccounts.isEmpty()) {
            return;
        }

        Set<Id> changedAccountIds = new Set<Id>();
        for (Account accountRec : newAccounts) {
            Account oldAccount = oldAccountMap == null ? null : oldAccountMap.get(accountRec.Id);
            if (accountRec.Id != null && oldAccount != null && hasRelevantChange(accountRec, oldAccount)) {
                changedAccountIds.add(accountRec.Id);
            }
        }

        changedAccountIds.removeAll(queuedAccountIds);
        if (changedAccountIds.isEmpty()) {
            return;
        }
        queuedAccountIds.addAll(changedAccountIds);

        if (Test.isRunningTest()) {
            syncOpenOpportunities(changedAccountIds);
        } else {
            System.enqueueJob(new AccountChildOpportunitySyncQueueable(changedAccountIds));
        }
    }

    @TestVisible
    static void syncOpenOpportunities(Set<Id> accountIds) {
        if (AutomationBypass.bypassFlows(BYPASS_KEY) || accountIds == null || accountIds.isEmpty()) {
            return;
        }

        Map<Id, Account> accountsById = new Map<Id, Account>([
            SELECT Id, Name, CurrencyIsoCode, Customer_Status__c,
                Contracted_Fleet_Size__c, Contracted_Shore_Size__c, Subscription_Annual_Order_Value__c,
                Fleet_Contracted_Fleet_Size__c, Fleet_Contracted_Shore_Size__c, Fleet_Subscription_Annual_Order_Value__c,
                Crew_Contracted_Fleet_Size__c, Crew_Contracted_Shore_Size__c, Crew_Subscription_Annual_Order_Value__c,
                L_A_Contracted_Fleet_Size__c, L_A_Contracted_Shore_Size__c, L_A_Subscription_Annual_Order_Value__c,
                Marine_Regulations_Contracted_Fleet_Size__c,
                Marine_Regulations_Contracted_Shore_Size__c,
                Marine_Regulations_Subscription_Annual_O__c
            FROM Account
            WHERE Id IN :accountIds
        ]);
        if (accountsById.isEmpty()) {
            return;
        }

        List<Opportunity> openOpportunities = [
            SELECT Id, AccountId, CurrencyIsoCode, IsClosed, Business_Unit__c, Sales_Type__c,
                Existing_Opportunity_Type__c, Contract_Type__c, OLP_Transition__c,
                Account_Name__c, Validation_Toggle__c, Customer_Status_List__c,
                Account_Customer_Status__c, Account_Contracted_Fleet_Size__c,
                Account_Contracted_Shore_Size__c, Account_Subscription_Annual_Order_Value__c,
                Product_Solutions__r.Product_Area_Status__c
            FROM Opportunity
            WHERE AccountId IN :accountsById.keySet()
              AND IsClosed = false
        ];
        if (openOpportunities.isEmpty()) {
            return;
        }

        Map<String, Decimal> conversionRatesByIsoCode = getConversionRates(accountsById.values(), openOpportunities);
        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
        for (Opportunity opportunityRec : openOpportunities) {
            Account accountRec = accountsById.get(opportunityRec.AccountId);
            Opportunity updates = buildOpportunityUpdate(accountRec, opportunityRec, conversionRatesByIsoCode);
            if (updates != null) {
                opportunitiesToUpdate.add(updates);
            }
        }

        if (!opportunitiesToUpdate.isEmpty()) {
            update opportunitiesToUpdate;
        }
    }

    private static Opportunity buildOpportunityUpdate(
        Account accountRec,
        Opportunity opportunityRec,
        Map<String, Decimal> conversionRatesByIsoCode
    ) {
        if (accountRec == null || opportunityRec == null) {
            return null;
        }

        BusinessUnitValues values = getBusinessUnitValues(accountRec, opportunityRec, conversionRatesByIsoCode);
        Opportunity updates = new Opportunity(Id = opportunityRec.Id);
        Boolean changed = false;

        if (opportunityRec.Account_Name__c != accountRec.Name) {
            updates.Account_Name__c = accountRec.Name;
            changed = true;
        }
        Boolean newToggle = opportunityRec.Validation_Toggle__c != true;
        if (opportunityRec.Validation_Toggle__c != newToggle) {
            updates.Validation_Toggle__c = newToggle;
            changed = true;
        }
        if (opportunityRec.Customer_Status_List__c != accountRec.Customer_Status__c) {
            updates.Customer_Status_List__c = accountRec.Customer_Status__c;
            changed = true;
        }
        if (opportunityRec.Account_Customer_Status__c != values.customerStatus) {
            updates.Account_Customer_Status__c = values.customerStatus;
            changed = true;
        }
        if (opportunityRec.Account_Contracted_Fleet_Size__c != values.contractedFleetSize) {
            updates.Account_Contracted_Fleet_Size__c = values.contractedFleetSize;
            changed = true;
        }
        if (opportunityRec.Account_Contracted_Shore_Size__c != values.contractedShoreSize) {
            updates.Account_Contracted_Shore_Size__c = values.contractedShoreSize;
            changed = true;
        }
        if (opportunityRec.Account_Subscription_Annual_Order_Value__c != values.subscriptionAnnualOrderValue) {
            updates.Account_Subscription_Annual_Order_Value__c = values.subscriptionAnnualOrderValue;
            changed = true;
        }

        OpportunityTypeUpdate typeUpdate = getOpportunityTypeUpdate(accountRec, opportunityRec, values.customerStatus);
        if (typeUpdate.existingOpportunityType != null &&
            opportunityRec.Existing_Opportunity_Type__c != typeUpdate.existingOpportunityType) {
            updates.Existing_Opportunity_Type__c = typeUpdate.existingOpportunityType;
            changed = true;
        }
        if (typeUpdate.contractType != null && opportunityRec.Contract_Type__c != typeUpdate.contractType) {
            updates.Contract_Type__c = typeUpdate.contractType;
            changed = true;
        }

        return changed ? updates : null;
    }

    private static BusinessUnitValues getBusinessUnitValues(
        Account accountRec,
        Opportunity opportunityRec,
        Map<String, Decimal> conversionRatesByIsoCode
    ) {
        BusinessUnitValues values = new BusinessUnitValues();
        values.customerStatus = opportunityRec.Product_Solutions__r == null
            ? null
            : opportunityRec.Product_Solutions__r.Product_Area_Status__c;

        if (FLEET_BUSINESS_UNITS.contains(opportunityRec.Business_Unit__c)) {
            values.contractedFleetSize = accountRec.Fleet_Contracted_Fleet_Size__c;
            values.contractedShoreSize = accountRec.Fleet_Contracted_Shore_Size__c;
            values.subscriptionAnnualOrderValue = convertCurrency(
                accountRec.Fleet_Subscription_Annual_Order_Value__c,
                accountRec.CurrencyIsoCode,
                opportunityRec.CurrencyIsoCode,
                conversionRatesByIsoCode
            );
        } else if (CREW_BUSINESS_UNITS.contains(opportunityRec.Business_Unit__c)) {
            values.contractedFleetSize = accountRec.Crew_Contracted_Fleet_Size__c;
            values.contractedShoreSize = accountRec.Crew_Contracted_Shore_Size__c;
            values.subscriptionAnnualOrderValue = convertCurrency(
                accountRec.Crew_Subscription_Annual_Order_Value__c,
                accountRec.CurrencyIsoCode,
                opportunityRec.CurrencyIsoCode,
                conversionRatesByIsoCode
            );
        } else if (LEARNING_BUSINESS_UNITS.contains(opportunityRec.Business_Unit__c)) {
            values.contractedFleetSize = accountRec.L_A_Contracted_Fleet_Size__c;
            values.contractedShoreSize = accountRec.L_A_Contracted_Shore_Size__c;
            values.subscriptionAnnualOrderValue = convertCurrency(
                accountRec.L_A_Subscription_Annual_Order_Value__c,
                accountRec.CurrencyIsoCode,
                opportunityRec.CurrencyIsoCode,
                conversionRatesByIsoCode
            );
        } else if (MARINE_BUSINESS_UNITS.contains(opportunityRec.Business_Unit__c)) {
            values.contractedFleetSize = accountRec.Marine_Regulations_Contracted_Fleet_Size__c;
            values.contractedShoreSize = accountRec.Marine_Regulations_Contracted_Shore_Size__c;
            values.subscriptionAnnualOrderValue = convertCurrency(
                accountRec.Marine_Regulations_Subscription_Annual_O__c,
                accountRec.CurrencyIsoCode,
                opportunityRec.CurrencyIsoCode,
                conversionRatesByIsoCode
            );
        } else {
            values.contractedFleetSize = accountRec.Contracted_Fleet_Size__c;
            values.contractedShoreSize = accountRec.Contracted_Shore_Size__c;
            values.subscriptionAnnualOrderValue = convertCurrency(
                accountRec.Subscription_Annual_Order_Value__c,
                accountRec.CurrencyIsoCode,
                opportunityRec.CurrencyIsoCode,
                conversionRatesByIsoCode
            );
        }

        return values;
    }

    private static OpportunityTypeUpdate getOpportunityTypeUpdate(
        Account accountRec,
        Opportunity opportunityRec,
        String localCustomerStatus
    ) {
        OpportunityTypeUpdate result = new OpportunityTypeUpdate();
        String currentType = opportunityRec.Existing_Opportunity_Type__c;
        Boolean isOlpTransition = currentType == 'OLP Transition' || opportunityRec.OLP_Transition__c != null;
        if (isOlpTransition || currentType == 'Account Growth' || currentType == 'Renewal') {
            return result;
        }

        if (opportunityRec.Sales_Type__c == 'One-Time' && currentType != 'One-Time') {
            result.existingOpportunityType = 'One-Time';
            return result;
        }

        Boolean accountActive = accountRec.Customer_Status__c == 'Active';
        Boolean localActive = localCustomerStatus == 'Active';
        Boolean localPresent = localCustomerStatus != null;
        Boolean accountStatusPresent = accountRec.Customer_Status__c != null;

        if (accountActive && localActive && currentType != 'Up-sell') {
            result.existingOpportunityType = 'Up-sell';
            result.contractType = 'Existing Contract';
        } else if (accountActive && localPresent && !localActive && currentType != 'Cross-sell') {
            result.existingOpportunityType = 'Cross-sell';
            result.contractType = 'New Contract';
        } else if (!accountActive && accountStatusPresent && localPresent && !localActive && currentType != 'Whitespace') {
            result.existingOpportunityType = 'Whitespace';
            result.contractType = 'New Contract';
        }

        return result;
    }

    private static Map<String, Decimal> getConversionRates(List<Account> accounts, List<Opportunity> opportunities) {
        Set<String> isoCodes = new Set<String>();
        for (Account accountRec : accounts) {
            if (!String.isBlank(accountRec.CurrencyIsoCode)) {
                isoCodes.add(accountRec.CurrencyIsoCode);
            }
        }
        for (Opportunity opportunityRec : opportunities) {
            if (!String.isBlank(opportunityRec.CurrencyIsoCode)) {
                isoCodes.add(opportunityRec.CurrencyIsoCode);
            }
        }

        Map<String, Decimal> ratesByIsoCode = new Map<String, Decimal>();
        if (isoCodes.isEmpty()) {
            return ratesByIsoCode;
        }

        for (CurrencyType currencyType : [
            SELECT IsoCode, ConversionRate
            FROM CurrencyType
            WHERE IsoCode IN :isoCodes
        ]) {
            ratesByIsoCode.put(currencyType.IsoCode, currencyType.ConversionRate);
        }
        return ratesByIsoCode;
    }

    private static Decimal convertCurrency(
        Decimal amount,
        String fromIsoCode,
        String toIsoCode,
        Map<String, Decimal> conversionRatesByIsoCode
    ) {
        if (amount == null) {
            return null;
        }
        if (String.isBlank(fromIsoCode) || String.isBlank(toIsoCode) || fromIsoCode == toIsoCode) {
            return amount.setScale(2);
        }

        Decimal fromRate = conversionRatesByIsoCode.get(fromIsoCode);
        Decimal toRate = conversionRatesByIsoCode.get(toIsoCode);
        if (fromRate == null || toRate == null || fromRate == 0) {
            return amount.setScale(2);
        }

        return ((amount / fromRate) * toRate).setScale(2);
    }

    private static Boolean hasRelevantChange(Account accountRec, Account oldAccount) {
        return accountRec.Name != oldAccount.Name ||
            accountRec.CurrencyIsoCode != oldAccount.CurrencyIsoCode ||
            accountRec.Customer_Status__c != oldAccount.Customer_Status__c ||
            accountRec.Contracted_Fleet_Size__c != oldAccount.Contracted_Fleet_Size__c ||
            accountRec.Contracted_Shore_Size__c != oldAccount.Contracted_Shore_Size__c ||
            accountRec.Subscription_Annual_Order_Value__c != oldAccount.Subscription_Annual_Order_Value__c ||
            accountRec.Fleet_Contracted_Fleet_Size__c != oldAccount.Fleet_Contracted_Fleet_Size__c ||
            accountRec.Fleet_Contracted_Shore_Size__c != oldAccount.Fleet_Contracted_Shore_Size__c ||
            accountRec.Fleet_Subscription_Annual_Order_Value__c != oldAccount.Fleet_Subscription_Annual_Order_Value__c ||
            accountRec.Crew_Contracted_Fleet_Size__c != oldAccount.Crew_Contracted_Fleet_Size__c ||
            accountRec.Crew_Contracted_Shore_Size__c != oldAccount.Crew_Contracted_Shore_Size__c ||
            accountRec.Crew_Subscription_Annual_Order_Value__c != oldAccount.Crew_Subscription_Annual_Order_Value__c ||
            accountRec.L_A_Contracted_Fleet_Size__c != oldAccount.L_A_Contracted_Fleet_Size__c ||
            accountRec.L_A_Contracted_Shore_Size__c != oldAccount.L_A_Contracted_Shore_Size__c ||
            accountRec.L_A_Subscription_Annual_Order_Value__c != oldAccount.L_A_Subscription_Annual_Order_Value__c ||
            accountRec.Marine_Regulations_Contracted_Fleet_Size__c != oldAccount.Marine_Regulations_Contracted_Fleet_Size__c ||
            accountRec.Marine_Regulations_Contracted_Shore_Size__c != oldAccount.Marine_Regulations_Contracted_Shore_Size__c ||
            accountRec.Marine_Regulations_Subscription_Annual_O__c != oldAccount.Marine_Regulations_Subscription_Annual_O__c;
    }

    private class BusinessUnitValues {
        String customerStatus;
        Decimal contractedFleetSize;
        Decimal contractedShoreSize;
        Decimal subscriptionAnnualOrderValue;
    }

    private class OpportunityTypeUpdate {
        String existingOpportunityType;
        String contractType;
    }

    private class AccountChildOpportunitySyncQueueable implements Queueable {
        private Set<Id> accountIds;

        AccountChildOpportunitySyncQueueable(Set<Id> accountIds) {
            this.accountIds = accountIds == null ? new Set<Id>() : new Set<Id>(accountIds);
        }

        public void execute(QueueableContext context) {
            AccountChildOpportunitySyncService.syncOpenOpportunities(accountIds);
        }
    }
}
