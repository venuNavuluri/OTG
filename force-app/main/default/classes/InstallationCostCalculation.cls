public with sharing class InstallationCostCalculation {
    public class QuoteLineGroupCalculation {
        @AuraEnabled public Id quoteLineGroupId;
        @AuraEnabled public String name;
        @AuraEnabled public String currencyIsoCode;
        @AuraEnabled public Decimal installationPrice;
        @AuraEnabled public Decimal currentPrice;
        @AuraEnabled public String products;
        @AuraEnabled public String productChangeType;
        @AuraEnabled public String installationChangeType;
        @AuraEnabled public Boolean createdFromPackage;
    }

    public static void updateInstallationPriceByQuotes(Set<Id> quoteIds) {
        updateInstallationPriceByQuotes(quoteIds, Date.today());
    }

    public static void updateInstallationPriceByQuotes(Set<Id> quoteIds, Date asOfDate) {
        List<QuoteLineGroupCalculation> calculations = calculateQuoteLineGroups(quoteIds, asOfDate);

        List<SBQQ__QuoteLineGroup__c> toUpdate = new List<SBQQ__QuoteLineGroup__c>();
        for (QuoteLineGroupCalculation calc : calculations) {
            SBQQ__QuoteLineGroup__c upd = new SBQQ__QuoteLineGroup__c(Id = calc.quoteLineGroupId);
            upd.put('Installation_Price__c', calc.installationPrice);
            upd.put('Products__c', calc.products);
            upd.put('Current_Price__c', calc.currentPrice);
            if (calc.productChangeType != null) {
                upd.put('Product_Change_Type__c', calc.productChangeType);
            }
            toUpdate.add(upd);
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    @AuraEnabled(cacheable=false)
    public static List<QuoteLineGroupCalculation> previewQuoteLineGroupInstallationCosts(Id quoteId) {
        if (quoteId == null) return new List<QuoteLineGroupCalculation>();
        return calculateQuoteLineGroups(new Set<Id>{ quoteId }, resolveEffectiveDate(quoteId));
    }

    public static Date resolveEffectiveDate(Id quoteId) {
        if (quoteId == null) return Date.today();

        SBQQ__Quote__c q = [
            SELECT SBQQ__Type__c, SBQQ__StartDate__c
            FROM SBQQ__Quote__c
            WHERE Id = :quoteId
            LIMIT 1
        ];

        if (q.SBQQ__StartDate__c == null) return Date.today();
        return (q.SBQQ__Type__c == 'Renewal' || q.SBQQ__StartDate__c >= Date.today())
            ? q.SBQQ__StartDate__c
            : Date.today();
    }

    private static List<QuoteLineGroupCalculation> calculateQuoteLineGroups(Set<Id> quoteIds, Date asOfDate) {
        if (quoteIds == null || quoteIds.isEmpty()) return new List<QuoteLineGroupCalculation>();
        if (asOfDate == null) asOfDate = Date.today();

        List<SBQQ__QuoteLine__c> lines = [
            SELECT SBQQ__Group__c,
                   Annual_Subscription_Value__c,
                   Change_Type__c,
                   SBQQ__StartDate__c,
                   SBQQ__EndDate__c,
                   SBQQ__EffectiveStartDate__c,
                   SBQQ__EffectiveEndDate__c,
                   SBQQ__Quote__c
            FROM SBQQ__QuoteLine__c
            WHERE SBQQ__Quote__c IN :quoteIds
              AND SBQQ__Group__c != NULL
        ];

        Map<Id, Decimal> installByGroup = new Map<Id, Decimal>();
        for (SBQQ__QuoteLine__c ql : lines) {
            if (ql.Change_Type__c == 'Cancel') continue;

            Date startDate = (ql.SBQQ__StartDate__c != null)
                ? ql.SBQQ__StartDate__c
                : ql.SBQQ__EffectiveStartDate__c;

            Date endDate = (ql.SBQQ__EndDate__c != null)
                ? ql.SBQQ__EndDate__c
                : ql.SBQQ__EffectiveEndDate__c;

            // require both dates to evaluate "active"
            if (startDate == null || endDate == null) continue;
            if (startDate <= asOfDate && endDate >= asOfDate) {
                Decimal val = (ql.Annual_Subscription_Value__c == null) ? 0 : ql.Annual_Subscription_Value__c;
                installByGroup.put(ql.SBQQ__Group__c,
                    (installByGroup.containsKey(ql.SBQQ__Group__c) ? installByGroup.get(ql.SBQQ__Group__c) : 0) + val
                );
            }
        }
        // round to 2dp for consistency
        for (Id gId : new List<Id>(installByGroup.keySet())) {
            installByGroup.put(gId, installByGroup.get(gId).setScale(2));
        }

        List<SBQQ__QuoteLineGroup__c> groupsWithLines = [
            SELECT Id,
                   Name,
                   CurrencyIsoCode,
                   InstallationChangeType__c,
                   Installation_Change_Type__c,
                   Created_From_Package__c,
                   SBQQ__Quote__r.SBQQ__MasterContract__c,
                   SBQQ__Quote__r.SBQQ__Type__c,
                   SBQQ__Quote__r.SBQQ__StartDate__c,
                   (SELECT Id,
                           SBQQ__ProductName__c,
                           Change_Type__c,
                           Previous_Subscription_Net_Total__c,
                           SBQQ__RenewedSubscription__c,
                    	   SBQQ__RenewedSubscription__r.Annual_Subscription_Value__c,
                           SBQQ__RenewedSubscription__r.SBQQ__EndDate__c ,
                           SBQQ__RenewedSubscription__r.SBQQ__SegmentEndDate__c
                    FROM SBQQ__LineItems__r)
            FROM SBQQ__QuoteLineGroup__c
            WHERE SBQQ__Quote__c IN :quoteIds
        ];
        
        Map<Id, String>  productsByGroup      = new Map<Id, String>();
        Map<Id, Decimal> currentPriceByGroup  = new Map<Id, Decimal>();
        Map<Id, String>  productChangeByGroup = new Map<Id, String>();
        
        
        
        for (SBQQ__QuoteLineGroup__c g : groupsWithLines) {
            Set<String> prodNames = new Set<String>();
            Decimal currentSum = 0;
            Boolean hasCancel = false;
            Boolean hasAddOrNew = false;
            
            Date qStart = g.SBQQ__Quote__r.SBQQ__StartDate__c;
            Boolean isRenewal = (g.SBQQ__Quote__r.SBQQ__Type__c == 'Renewal');
            Date targetSegEnd = (isRenewal && qStart != null) ? qStart.addDays(-1) : null;
        
            if (g.SBQQ__LineItems__r != null) {
                for (SBQQ__QuoteLine__c ql : g.SBQQ__LineItems__r) {
                    // Build Products__c as before (exclude cancels)
                    if (ql.Change_Type__c != 'Cancel' && !String.isBlank(ql.SBQQ__ProductName__c)) {
                        prodNames.add(ql.SBQQ__ProductName__c.trim());
                    }
        
                    // Track changes for Product_Change_Type__c
                    if (ql.Change_Type__c == 'Cancel') hasCancel = true;
                    if (ql.Change_Type__c == 'New')    hasAddOrNew = true;
        
                    // Current_Price__c: ONLY for Renewal, and ONLY when renewed subscription segment end == Quote.StartDate - 1
                    if (isRenewal && targetSegEnd != null && ql.SBQQ__RenewedSubscription__c != null) {
                        Date segEnd   = ql.SBQQ__RenewedSubscription__r.SBQQ__SegmentEndDate__c;
                        Date regEnd = ql.SBQQ__RenewedSubscription__r.SBQQ__EndDate__c ;
        
                        Boolean matches =
                            (segEnd != null  && segEnd == targetSegEnd) ||
                            (segEnd == null && regEnd != null && regEnd == targetSegEnd);
        
                        if (matches && ql.SBQQ__RenewedSubscription__r.Annual_Subscription_Value__c != null) {
                            currentSum += ql.SBQQ__RenewedSubscription__r.Annual_Subscription_Value__c;
                        }
                    }
                }
            }
        
            String pct;
            if (g.Created_From_Package__c == false) {
                pct = 'New Package';                                  
            } else if (hasCancel && hasAddOrNew) {
                pct = 'Products Added & Removed';
            } else if (hasCancel) {
                pct = 'Product Removed';
            } else if (hasAddOrNew) {
                pct = 'New Product Added';
            } else {
                pct = 'No Change'; // or '' to clear
            }
        
            productsByGroup.put(g.Id, String.join(new List<String>(prodNames), ';'));
            currentPriceByGroup.put(g.Id, currentSum);
            productChangeByGroup.put(g.Id, pct);
        }

        List<QuoteLineGroupCalculation> calculations = new List<QuoteLineGroupCalculation>();
        for (SBQQ__QuoteLineGroup__c g : groupsWithLines) {
            QuoteLineGroupCalculation calc = new QuoteLineGroupCalculation();
            calc.quoteLineGroupId = g.Id;
            calc.name = g.Name;
            calc.currencyIsoCode = g.CurrencyIsoCode;
            calc.createdFromPackage = g.Created_From_Package__c;

            Decimal install = installByGroup.containsKey(g.Id) ? installByGroup.get(g.Id) : 0;
            calc.installationPrice = install;

            String products = productsByGroup.containsKey(g.Id) ? productsByGroup.get(g.Id) : '';
            calc.products = products;

            Decimal curr = currentPriceByGroup.containsKey(g.Id) ? currentPriceByGroup.get(g.Id) : 0;
            calc.currentPrice = curr.setScale(2);
            calc.productChangeType = productChangeByGroup.get(g.Id);
            calc.installationChangeType = String.isNotBlank(g.InstallationChangeType__c)
                ? g.InstallationChangeType__c
                : g.Installation_Change_Type__c;

            calculations.add(calc);
        }

        return calculations;
    }
}
