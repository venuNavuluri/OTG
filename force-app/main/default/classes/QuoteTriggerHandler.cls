/**
* @description       : Trigger Handler for Quotes in Salesforce CPQ
*                      - Handles Quote insert, update, and approval workflows
*                      - Creates Quote Line Groups & Packages
*                      - Performs validation on Installation counts
*                      - Updates Quote End Date and Installation Costs
*                      - Logs structured information for debugging
*
* @author            : Venu Navuluri
* @last modified by  : Venu Navuluri
**/
public class QuoteTriggerHandler extends TriggerHandler {
    
    // Constants for Hardcoded Values
    private static final String STATUS_APPROVED = 'Approved';
    private static final String STATUS_DRAFT = 'Draft';
    private static final String QUOTE_TYPE_AMENDMENT = 'Amendment';
    private static final String QUOTE_TYPE_RENEWAL = 'Renewal';
    private static final String CHARGE_TYPE_ONE_TIME = 'One-Time';
    private static final String INSTALLATION_TERMINATED = 'Terminated';
    private static final Integer DEFAULT_SUBSCRIPTION_TERM = 12;
   
    
    public override void beforeInsert() {
        QuoteTriggerHelper.updateQlgCheckbox(Trigger.new);
        updateQuoteEndDate((List<SBQQ__Quote__c>) Trigger.new);
    }
    public override void afterInsert() {
        createQuoteLineGroups((Map<Id, SBQQ__Quote__c>) Trigger.newMap);
        QuoteTriggerHelper.createDummyQLG((Map<Id, SBQQ__Quote__c>) Trigger.newMap);
    }
    protected override void afterDelete() {
    }
    
    public override void beforeUpdate() {
        //checkExistingQuotes((List<SBQQ__Quote__c>) Trigger.new, (Map<Id, SBQQ__Quote__c>) Trigger.oldMap);
        QuoteTriggerHelper.validateInstallationCount(
            (Map<Id, SBQQ__Quote__c>) Trigger.newMap,
            (Map<Id, SBQQ__Quote__c>) Trigger.oldMap
        );
        updateQuoteEndDate((List<SBQQ__Quote__c>) Trigger.new);
    }
    
    public override void afterUpdate() {
        
        // Step 1: Collect approved Quote IDs
        Set<Id> approvedQuoteIds = new Set<Id>();
        for (SBQQ__Quote__c newQuote : (List<SBQQ__Quote__c>) Trigger.new) {
            SBQQ__Quote__c oldQuote = (SBQQ__Quote__c) Trigger.oldMap.get(newQuote.Id);
            
            // Check if the status changed to Approved
            if (newQuote.SBQQ__Status__c == 'Approved' && oldQuote.SBQQ__Status__c != 'Approved') {
                approvedQuoteIds.add(newQuote.Id);
            }
        }
        
        createPackageRecords(
            (Map<Id, SBQQ__Quote__c>) Trigger.newMap,
            (Map<Id, SBQQ__Quote__c>) Trigger.oldMap
        );
        
        // Step 2: Call the method to calculate Current_Price__c for Quote Line Groups
        if (!approvedQuoteIds.isEmpty()) {
            updateInstalltionCost(approvedQuoteIds);
        }
        
    }
    
    public void createPackageRecords(
    Map<Id, SBQQ__Quote__c> newQtMap,
    Map<Id, SBQQ__Quote__c> oldQtMap
) {
    try {
        Logger.debug('START: createPackageRecords');

        // Step 1: Collect approved quotes
        List<Id> approvedQuoteIds = new List<Id>();
        for (SBQQ__Quote__c qt : newQtMap.values()) {
            if (
                qt.SBQQ__Status__c == 'Approved' &&
                oldQtMap.get(qt.Id).SBQQ__Status__c != 'Approved' &&
                (qt.Auto_Installation__c == false && qt.Auto_Termination__c == false)
            ) {
                approvedQuoteIds.add(qt.Id);
            }
        }

        Logger.debug('Approved Quote IDs: ' + approvedQuoteIds);

        if (approvedQuoteIds.isEmpty()) {
            Logger.debug('No approved quotes to process.');
            Logger.saveLog();
            return;
        }

        // Step 2: Query existing packages linked to the approved quotes
        Map<String, Package__c> qlgToPackageMap = new Map<String, Package__c>();
        for (Package__c existingPackage : [
            SELECT Id, Name, Quote_Line_Group__c, Quote__c, Installation_Quantity__c
            FROM Package__c
            WHERE Quote__c IN :approvedQuoteIds
        ]) {
            qlgToPackageMap.put(existingPackage.Quote_Line_Group__c, existingPackage);
        }

        Logger.debug('Fetched existing packages: ' + qlgToPackageMap.keySet());

        // Step 3: Query QuoteLineGroups
        List<SBQQ__QuoteLineGroup__c> qlgList = [
            SELECT Id, Name, Installation_Quantity__c, Number_of_Rapid_Titles__c,
                   Number_of_Special_Products__c, Number_of_Virtual_Classrooms__c,
                   User_Quantity__c, CurrencyISOCode, SBQQ__Quote__c
            FROM SBQQ__QuoteLineGroup__c
            WHERE SBQQ__Quote__c IN :approvedQuoteIds
        ];

        Logger.debug('QLGs to process: ' + qlgList.size());

        // Step 4: Track records to insert/update
        List<Package__c> newPackages = new List<Package__c>();
        List<Package__c> packagesToUpdate = new List<Package__c>();
        Set<Id> packagesToUpdateIds = new Set<Id>();

        List<SBQQ__QuoteLineGroup__c> qlgToUpdate = new List<SBQQ__QuoteLineGroup__c>();
        Set<Id> qlgToUpdateIds = new Set<Id>();

        for (SBQQ__QuoteLineGroup__c qlg : qlgList) {
            Logger.debug('Processing QLG: ' + qlg.Id);

            if (qlgToPackageMap.containsKey(qlg.Id)) {
                Package__c existingPackage = qlgToPackageMap.get(qlg.Id);
                Boolean shouldUpdate = false;

                if (existingPackage.Installation_Quantity__c != qlg.Installation_Quantity__c) {
                    existingPackage.Installation_Quantity__c = qlg.Installation_Quantity__c;
                    shouldUpdate = true;
                }

                if (existingPackage.Name != qlg.Name) {
                    existingPackage.Name = qlg.Name;
                    shouldUpdate = true;
                }

                if (shouldUpdate && !packagesToUpdateIds.contains(existingPackage.Id)) {
                    packagesToUpdate.add(existingPackage);
                    packagesToUpdateIds.add(existingPackage.Id);
                }

                if ((existingPackage.Quote_Line_Group__c == null || existingPackage.Quote_Line_Group__c != qlg.Id)
                    && !qlgToUpdateIds.contains(qlg.Id)) {
                    qlgToUpdate.add(new SBQQ__QuoteLineGroup__c(
                        Id = qlg.Id,
                        Package__c = existingPackage.Id
                    ));
                    qlgToUpdateIds.add(qlg.Id);
                }

            } else {
                Logger.debug('Creating new Package for QLG: ' + qlg.Id);

                Package__c newPackage = new Package__c(
                    Account__c = newQtMap.get(qlg.SBQQ__Quote__c).SBQQ__Account__c,
                    Contract__c = newQtMap.get(qlg.SBQQ__Quote__c).SBQQ__MasterContract__c,
                    Installation_Quantity__c = qlg.Installation_Quantity__c,
                    Number_of_Rapid_Titles__c = qlg.Number_of_Rapid_Titles__c,
                    Number_of_Special_Products__c = qlg.Number_of_Special_Products__c,
                    Number_of_Virtual_Classrooms__c = qlg.Number_of_Virtual_Classrooms__c,
                    Package_Name__c = qlg.Name,
                    Name = qlg.Name,
                    CurrencyISOCode = qlg.CurrencyISOCode,
                    User_Quantity__c = qlg.User_Quantity__c,
                    Quote__c = qlg.SBQQ__Quote__c,
                    Quote_Line_Group__c = qlg.Id
                );

                newPackages.add(newPackage);
            }
        }

        // Step 5: Insert new packages
        if (!newPackages.isEmpty()) {
            insert newPackages;
            Logger.debug('Inserted new packages: ' + newPackages.size());

            for (Package__c newPackage : newPackages) {
                if (!qlgToUpdateIds.contains(newPackage.Quote_Line_Group__c)) {
                    qlgToUpdate.add(new SBQQ__QuoteLineGroup__c(
                        Id = newPackage.Quote_Line_Group__c,
                        Package__c = newPackage.Id
                    ));
                    qlgToUpdateIds.add(newPackage.Quote_Line_Group__c);
                }
            }
        }

        // Step 6: Update existing packages
        if (!packagesToUpdate.isEmpty()) {
            update packagesToUpdate;
            Logger.debug('Updated packages: ' + packagesToUpdate.size());
            Logger.saveLog();
        }

        // Step 7: Update QLGs with package links
        if (!qlgToUpdate.isEmpty()) {
            update qlgToUpdate;
            Logger.debug('Updated QLGs with package references: ' + qlgToUpdate.size());
            Logger.saveLog();
        }

        Logger.debug('END: createPackageRecords');
    } catch (Exception ex) {
        Logger.error(
            'Exception in createPackageRecords:\n' +
            'Message: ' + ex.getMessage() + '\n' +
            'Line: ' + ex.getLineNumber() + '\n' +
            'StackTrace: ' + ex.getStackTraceString()
        );
        Logger.saveLog();
    }
}
    
    /**
    * @description Checks if existing Quotes have unprocessed draft Orders before approving.
    /*
   /* public void checkExistingQuotes(List<SBQQ__Quote__c> newQtList, Map<Id, SBQQ__Quote__c> oldQtMap) {
        Map<Id, SBQQ__Quote__c> contractQuoteMap = new Map<Id, SBQQ__Quote__c>();
        
        for (SBQQ__Quote__c qt : newQtList) {
            if (qt.SBQQ__Type__c == QUOTE_TYPE_AMENDMENT &&
                qt.SBQQ__Status__c != oldQtMap.get(qt.Id).SBQQ__Status__c &&
                qt.SBQQ__Status__c == STATUS_APPROVED) {
                    contractQuoteMap.put(qt.SBQQ__MasterContract__c, qt);
                }
        }
        
        if (contractQuoteMap.isEmpty()) return;
        
        // Fetch Orders related to these contracts and retrieve associated Quote details
        List<Order> orders = [
            SELECT Id, Name, SBQQ__Quote__c, SBQQ__Quote__r.Name
            FROM Order 
            WHERE Status != 'Activated' 
            AND SBQQ__Quote__c IN :contractQuoteMap.keySet()
        ];
        
        Map<Id, List<String>> contractOrderMap = new Map<Id, List<String>>();
        
        for (Order ord : orders) {
            if (!contractOrderMap.containsKey(ord.SBQQ__Quote__c)) {
                contractOrderMap.put(ord.SBQQ__Quote__c, new List<String>());
            }
            // Get the related Quote Name using SBQQ__Quote__r
            if (ord.SBQQ__Quote__r != null) {
                contractOrderMap.get(ord.SBQQ__Quote__c).add(ord.SBQQ__Quote__r.Name);
            }
        }
        
        // Add Errors for Quotes that have related draft Orders
        for (Id contractId : contractOrderMap.keySet()) {
            String quoteNames = String.join(contractOrderMap.get(contractId), ', ');
            contractQuoteMap.get(contractId).addError(
                'Please close the existing draft orders related to the quote: ' + quoteNames
            );
        }
    } /*
    
    
    /**
    * @description Updates the Quote End Date based on Subscription Term or Master Contract End Date.
    */
    public void updateQuoteEndDate(List<SBQQ__Quote__c> newQtList) {
    Map<Id, SBQQ__Quote__c> amendmentQuoteMap = new Map<Id, SBQQ__Quote__c>();

    for (SBQQ__Quote__c qt : newQtList) {
        if (qt.SBQQ__Type__c == QUOTE_TYPE_AMENDMENT && qt.SBQQ__MasterContract__c != null) {
            amendmentQuoteMap.put(qt.SBQQ__MasterContract__c, qt);
        } else if (qt.SBQQ__StartDate__c != null) {
            Integer term = qt.SBQQ__SubscriptionTerm__c != null
                ? Integer.valueOf(qt.SBQQ__SubscriptionTerm__c)
                : DEFAULT_SUBSCRIPTION_TERM;

            qt.SBQQ__EndDate__c = qt.SBQQ__StartDate__c.addMonths(term).addDays(-1);
        }
    }

    if (!amendmentQuoteMap.isEmpty()) {
        List<Contract> contracts = [
            SELECT Id, EndDate
            FROM Contract
            WHERE Id IN :amendmentQuoteMap.keySet()
        ];

        for (Contract ctr : contracts) {
            SBQQ__Quote__c qt = amendmentQuoteMap.get(ctr.Id);
            if (qt != null) {
                qt.SBQQ__EndDate__c = ctr.EndDate;
            }
        }
    }
}
    
    public void createQuoteLineGroups(Map<Id, SBQQ__Quote__c> newQuoteMap)
    {
        try
        {
            if (newQuoteMap.isEmpty()) {
                return;
            }
            
            Map<Id, Id> quoteIdMap = new Map<Id, Id>();
            Map<Id, Id> contractIdToQuoteIdMap = new Map<Id, Id>();
            Map<Id, Id> opportunityIdToQuoteIdMap = new Map<Id, Id>();
            
            for (SBQQ__Quote__c quote : newQuoteMap.values()) {
                if (quote.SBQQ__Type__c == 'Amendment' && quote.SBQQ__MasterContract__c != null) {
                    contractIdToQuoteIdMap.put(quote.SBQQ__MasterContract__c, quote.Id);
                } else if (quote.SBQQ__Type__c == 'Renewal') {
                    opportunityIdToQuoteIdMap.put(quote.SBQQ__Opportunity2__c, quote.Id);
                }
            }
            
            if (!opportunityIdToQuoteIdMap.isEmpty()) {
                List<Opportunity> opportunities = [
                    SELECT Id, SBQQ__RenewedContract__c
                    FROM Opportunity
                    WHERE Id IN :opportunityIdToQuoteIdMap.keySet()
                ];
                
                for (Opportunity opportunity : opportunities) {
                    contractIdToQuoteIdMap.put(opportunity.SBQQ__RenewedContract__c, opportunityIdToQuoteIdMap.get(opportunity.Id));
                }
            }
            
            
            System.debug('contractIdToQuoteIdMap.keySet() --> ' + contractIdToQuoteIdMap.keySet());
            
            if (!contractIdToQuoteIdMap.isEmpty()) {
                List<Package__c> packages = [
                    SELECT Id, Name, CurrencyISOCode, Installation_Quantity__c, Contract__c,Number_of_Special_Products__c,User_Quantity__c,Number_of_Virtual_Classrooms__c
                    FROM Package__c
                    WHERE Contract__c IN :contractIdToQuoteIdMap.keySet()
                ];
                
                Map<Id, List<Package__c>> contractToPackagesMap = new Map<Id, List<Package__c>>();
                for (Package__c packageObj : packages) {
                    if (!contractToPackagesMap.containsKey(packageObj.Contract__c)) {
                        contractToPackagesMap.put(packageObj.Contract__c, new List<Package__c>());
                    }
                    contractToPackagesMap.get(packageObj.Contract__c).add(packageObj);
                }
                Map<Package__c, SBQQ__QuoteLineGroup__c> packagesToUpdateMap = new Map<Package__c, SBQQ__QuoteLineGroup__c>();
                List<SBQQ__QuoteLineGroup__c> newQuoteLineGroups = new List<SBQQ__QuoteLineGroup__c>();
                for (Id contractId : contractToPackagesMap.keySet()) {
                    Id quoteId = contractIdToQuoteIdMap.get(contractId);
                    if (quoteId != null && contractToPackagesMap.containsKey(contractId)) {
                        for (Package__c packageObj : contractToPackagesMap.get(contractId)) {
                            SBQQ__QuoteLineGroup__c quoteLineGroup = new SBQQ__QuoteLineGroup__c();
                            quoteLineGroup.SBQQ__Quote__c = quoteId;
                            quoteLineGroup.Name = packageObj.Name;
                            quoteLineGroup.Package__c = packageObj.Id;
                            quoteLineGroup.Installation_Quantity__c = packageObj.Installation_Quantity__c; 
                            quoteLineGroup.User_Quantity__c = packageObj.User_Quantity__c; 
                            quoteLineGroup.CurrencyIsoCode = packageObj.CurrencyISOCode;
                            quoteLineGroup.Package__c = packageObj.Id;
                            newQuoteLineGroups.add(quoteLineGroup);
                            
                            // Update Package record with new Quote ID
                            packageObj.Quote__c = quoteId;
                            packagesToUpdateMap.put(packageObj, quoteLineGroup);
                        }
                    }
                }
                
                if (!newQuoteLineGroups.isEmpty()) {
                    try {
                        System.debug('newQLG --> ' + newQuoteLineGroups);
                        insert newQuoteLineGroups;
                        for(Package__c pack : packagesToUpdateMap.keySet())
                        {
                            pack.Quote_Line_Group__c = packagesToUpdateMap.get(pack).Id;
                        }
                    } catch (DmlException ex) {
                        // Log exception for further analysis
                        System.debug('Error inserting QuoteLineGroup records: ' + ex.getMessage());
                        System.debug('ex --> ' + ex.getLineNumber());
                        System.debug('test --> ' + ex.getStackTraceString());
                        Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
                    }
                }
                
                if (!packagesToUpdateMap.isEmpty()) {
                    try {
                        List<Package__c> packagesToUpdate = new List<Package__c>();
                        packagesToUpdate.addAll(packagesToUpdateMap.keySet());
                        update packagesToUpdate;
                    } catch (DmlException ex) {
                        // Log exception for further analysis
                        System.debug('Error updating Package records: ' + ex.getMessage());
                        Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
                    }
                }
            }
        }
        catch(Exception ex)
        {
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
        }
    }    
    
     public static void updateInstalltionCost(Set<Id> approvedQuoteIds) {
    try {
        // Step 1: Fetch Quote Line Groups with Line Items and Installations
        List<SBQQ__QuoteLineGroup__c> quoteGroups = [
            SELECT Id, Name, Installation_Quantity__c, Package__c, SBQQ__Quote__r.SBQQ__Type__c, SBQQ__Quote__c,
                   SBQQ__Quote__r.SBQQ__Account__c, User_Quantity__c, CurrencyIsoCode,
                   (SELECT Id, Name, SBQQ__Product__c, SBQQ__ProductName__c, SBQQ__CustomerPrice__c, 
                            Change_Type__c, Previous_Subscription_Net_Total__c
                    FROM SBQQ__LineItems__r),
                   (SELECT Id, Name, Installation_Type__c, Vessel_Name__c, Vessel_Name__r.Name,
                            Organisation_Name__c, Organisation_Name__r.Name, Invoice_Account__c,
                            Invoice_Account__r.Name, Client__c, Client__r.Name, Delivery_Contact__c,
                            Delivery_Contact__r.Name
                    FROM Installations__r
                    WHERE Installation_Order_Status__c != 'Terminated')
            FROM SBQQ__QuoteLineGroup__c
            WHERE SBQQ__Quote__c IN :approvedQuoteIds
            ORDER BY Name ASC
        ];

        // Step 2: Fetch related Packages
        Map<Id, Package__c> packMap = new Map<Id, Package__c>([
            SELECT Id, Name, Installation_Quantity__c, InstallationCost__c, Quote__c, Quote__r.SBQQ__Type__c, Quote_Line_Group__c, Products__c,
                   (SELECT Id FROM Installations__r WHERE Installation_Order_Status__c != 'Terminated')
            FROM Package__c
            WHERE Quote__c IN :approvedQuoteIds
        ]);

        // Lists for DML
        List<Package__c> packListToUpdate = new List<Package__c>();
        List<SBQQ__QuoteLineGroup__c> quoteGroupsToUpdate = new List<SBQQ__QuoteLineGroup__c>();
        List<Installation__c> instList = new List<Installation__c>();

        // Step 3: Process each Quote Line Group
        for (SBQQ__QuoteLineGroup__c qlg : quoteGroups) {
            if (qlg.Package__c == null || !packMap.containsKey(qlg.Package__c)) continue;
            Package__c pack = packMap.get(qlg.Package__c);

            Decimal currentCost = pack.InstallationCost__c != null ? pack.InstallationCost__c : 0.0;
            Decimal installationPrice = 0.0;
            Decimal currentPrice = 0.0;

            String quoteType = qlg.SBQQ__Quote__r.SBQQ__Type__c;
            Set<String> productNames = new Set<String>();

            // For amendment, preload existing product names
            if (quoteType == 'Amendment' && !String.isBlank(pack.Products__c)) {
                List<String> existingNames = pack.Products__c.split(';');
                for (String name : existingNames) {
                    if (!String.isBlank(name)) {
                        productNames.add(name.trim());
                    }
                }
            }

            Set<String> processedProductActions = new Set<String>(); // For Amendment: ProductId:Action
            Set<Id> processedProductIds = new Set<Id>();             // For other quote types

            for (SBQQ__QuoteLine__c ql : qlg.SBQQ__LineItems__r) {
                if (ql.SBQQ__Product__c == null) continue;

                Decimal price = ql.SBQQ__CustomerPrice__c != null ? ql.SBQQ__CustomerPrice__c : 0.0;

                if (quoteType == 'Amendment') {
                    String key = ql.SBQQ__Product__c + ':' + ql.Change_Type__c;
                    if (!processedProductActions.contains(key)) {
                        processedProductActions.add(key);

                        if (ql.Change_Type__c == 'New') {
                            installationPrice += price;

                            if (!String.isBlank(ql.SBQQ__ProductName__c)) {
                                productNames.add(ql.SBQQ__ProductName__c.trim());
                            }
                        } else if (ql.Change_Type__c == 'Cancel') {
                            installationPrice -= price;

                            if (!String.isBlank(ql.SBQQ__ProductName__c)) {
                                productNames.remove(ql.SBQQ__ProductName__c.trim());
                            }
                        }
                    }
                } else {
                    if (!processedProductIds.contains(ql.SBQQ__Product__c)) {
                        processedProductIds.add(ql.SBQQ__Product__c);
                        installationPrice += price;

                        if (!String.isBlank(ql.SBQQ__ProductName__c)) {
                            productNames.add(ql.SBQQ__ProductName__c.trim());
                        }
                    }
                }

                // For Renewal quote current price
                if (quoteType == 'Renewal' && ql.Previous_Subscription_Net_Total__c != null) {
                    currentPrice += ql.Previous_Subscription_Net_Total__c;
                }
            }

            // Update Package installation cost
            pack.InstallationCost__c = (quoteType == 'Amendment') ? currentCost + installationPrice : installationPrice;
            pack.Products__c = String.join(new List<String>(productNames), ';');
            if (currentPrice != null) {
                pack.Previous_Cost__c = currentPrice;
            }
            packListToUpdate.add(pack);

            // Update Quote Line Group current price
            qlg.put('Current_Price__c', currentPrice);
            qlg.put('Installation_Price__c',installationPrice);
            quoteGroupsToUpdate.add(qlg);
        }

        // Step 4: DML updates
        if (!packListToUpdate.isEmpty()) {
            update packListToUpdate;
        }

        if (!quoteGroupsToUpdate.isEmpty()) {
            update quoteGroupsToUpdate;
        }

        // Step 5: Update Installations for Renewal Quotes
        for (Package__c pack : packMap.values()) {
            if (pack.Quote__r.SBQQ__Type__c == 'Renewal' && pack.Installations__r != null && !pack.Installations__r.isEmpty()) {
                for (Installation__c inst : pack.Installations__r) {
                    inst.Quote__c = pack.Quote__c;
                    inst.Quote_Line_Group__c = pack.Quote_Line_Group__c;
                    instList.add(inst);
                }
            }
        }

        if (!instList.isEmpty()) {
            update instList;
        }

    } catch (Exception ex) {
        System.debug('Error in updateInstalltionCost: ' + ex.getMessage());
        Logger.error('Error in updateInstalltionCost: ' + ex.getMessage());
    }
}
    private static final String CLASS_NAME = 'QuoteTriggerHandler';
    
    public static void handleBeforeInsert(List<SBQQ__Quote__c> newQuotes) {
        // 1. Filter amendment quotes with contracts
        List<SBQQ__Quote__c> amendmentQuotes = getAmendmentQuotes(newQuotes);
        if (amendmentQuotes.isEmpty()) return;
        
        // 2. Get all related contracts
        Map<Id, Contract> masterContracts = getMasterContracts(amendmentQuotes);
        
        // 3. Update quote currencies
        updateQuoteCurrencies(amendmentQuotes, masterContracts);
        
        // 4. Update opportunity currencies
        updateOpportunityCurrencies(amendmentQuotes, masterContracts);
    }
    
    private static List<SBQQ__Quote__c> getAmendmentQuotes(List<SBQQ__Quote__c> quotes) {
        List<SBQQ__Quote__c> amendmentQuotes = new List<SBQQ__Quote__c>();
        for (SBQQ__Quote__c quote : quotes) {
            if (quote.SBQQ__Type__c == 'Amendment' && 
                quote.SBQQ__MasterContract__c != null &&
                quote.SBQQ__Opportunity2__c != null) {
                amendmentQuotes.add(quote);
            }
        }
        return amendmentQuotes;
    }
    
    private static void updateQuoteCurrencies(List<SBQQ__Quote__c> amendmentQuotes, Map<Id, Contract> masterContracts) {
        for (SBQQ__Quote__c quote : amendmentQuotes) {
            Contract masterContract = masterContracts.get(quote.SBQQ__MasterContract__c);
            if (masterContract != null && quote.CurrencyIsoCode != masterContract.CurrencyIsoCode) {
                quote.CurrencyIsoCode = masterContract.CurrencyIsoCode;
            }
        }
    }
    
    private static void updateOpportunityCurrencies(List<SBQQ__Quote__c> amendmentQuotes, Map<Id, Contract> masterContracts) {
        // Get all opportunity IDs
        Set<Id> opportunityIds = new Set<Id>();
        for (SBQQ__Quote__c quote : amendmentQuotes) {
            opportunityIds.add(quote.SBQQ__Opportunity2__c);
        }
        
        // Query opportunities with their current currency
        Map<Id, Opportunity> opportunities = new Map<Id, Opportunity>([
            SELECT Id, CurrencyIsoCode 
            FROM Opportunity 
            WHERE Id IN :opportunityIds
            FOR UPDATE
        ]);
        
        // Prepare updates
        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
        for (SBQQ__Quote__c quote : amendmentQuotes) {
            Opportunity opp = opportunities.get(quote.SBQQ__Opportunity2__c);
            Contract contract = masterContracts.get(quote.SBQQ__MasterContract__c);
            
            if (opp != null && contract != null && opp.CurrencyIsoCode != contract.CurrencyIsoCode) {
                opp.CurrencyIsoCode = contract.CurrencyIsoCode;
                opportunitiesToUpdate.add(opp);
            }
        }
        
        // Perform update
        if (!opportunitiesToUpdate.isEmpty()) {
            update opportunitiesToUpdate;
        }
    }
    
    private static Map<Id, Contract> getMasterContracts(List<SBQQ__Quote__c> amendmentQuotes) {
        Set<Id> contractIds = new Set<Id>();
        for (SBQQ__Quote__c quote : amendmentQuotes) {
            contractIds.add(quote.SBQQ__MasterContract__c);
        }
        return new Map<Id, Contract>([
            SELECT Id, CurrencyIsoCode 
            FROM Contract 
            WHERE Id IN :contractIds
        ]);
    }
 
}