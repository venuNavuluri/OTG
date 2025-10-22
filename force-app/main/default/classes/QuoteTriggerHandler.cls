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
        // Block Amendment quote creation when open quotes or draft orders exist for the contract
        enforceNoOpenItemsForAmendment((List<SBQQ__Quote__c>) Trigger.new);

        QuoteTriggerHelper.updateQlgCheckbox(Trigger.new);
        updateQuoteEndDate((List<SBQQ__Quote__c>) Trigger.new);
        
        List<SBQQ__Quote__c> amendmentQuotes = getAmendmentQuotes(Trigger.new);
        if (amendmentQuotes.isEmpty()) return;
        
        Map<Id, Contract> masterContracts = getMasterContracts(amendmentQuotes);
        if (masterContracts.isEmpty()) return;
        
        updateOpportunityCurrencies(amendmentQuotes, masterContracts);
        updateQuoteCurrencies(amendmentQuotes, masterContracts);
    }
    public override void afterInsert() {
        createQuoteLineGroups((Map<Id, SBQQ__Quote__c>) Trigger.newMap);
        QuoteTriggerHelper.createDummyQLG((Map<Id, SBQQ__Quote__c>) Trigger.newMap);
    }
    protected override void afterDelete() {
    }
    
    public override void beforeUpdate() {
        
        // Check user-specific setting to determine bypass
        VRConfiguration__c userSetting = VRConfiguration__c.getInstance(UserInfo.getUserId());
        Boolean isBypassEnabled = userSetting != null && userSetting.Quote_Ordered_Validation__c;
        
        updateQuoteEndDate((List<SBQQ__Quote__c>) Trigger.new);
    }
    
    public override void afterUpdate() {
                Set<Id> approvedQuoteIds = new Set<Id>();
            
                for (SBQQ__Quote__c qNew : (List<SBQQ__Quote__c>) Trigger.new) {
                    SBQQ__Quote__c qOld = (SBQQ__Quote__c) Trigger.oldMap.get(qNew.Id);
                    Boolean isApprovedNow = qNew.SBQQ__Status__c == STATUS_APPROVED &&
                                            qOld.SBQQ__Status__c != STATUS_APPROVED;
                    if (isApprovedNow) {
                        approvedQuoteIds.add(qNew.Id);
                    }
                }
            
                if (!approvedQuoteIds.isEmpty()) {

                    Map<Id, SBQQ__Quote__c> approvedQuotes = new Map<Id, SBQQ__Quote__c>();
                    for (Id qId : approvedQuoteIds) {
                        approvedQuotes.put(qId, (SBQQ__Quote__c) Trigger.newMap.get(qId));
                    }
                    syncPackageRecords(approvedQuotes, (Map<Id, SBQQ__Quote__c>) Trigger.oldMap);
            
                    for (Id qId : approvedQuoteIds) {
                        SBQQ__Quote__c q = (SBQQ__Quote__c) Trigger.newMap.get(qId);
                        Date effDate = (q.SBQQ__Type__c == 'Renewal' || q.SBQQ__StartDate__c >= Date.today())
                                       ? q.SBQQ__StartDate__c
                                       : Date.today();
                
                        try {
                            // call your existing helper exactly as-is
                            InstallationCostCalculation.updateInstallationPriceByQuotes(
                                new Set<Id>{ q.Id }, effDate
                            );
                        } catch (Exception ex) {
                            Logger.error('InstallationCostCalculation failed for Quote ' + q.Id +
                                         ' | msg: ' + ex.getMessage() +
                                         ' | line: ' + ex.getLineNumber());
                            Logger.saveLog();
                        }
                    }
                    
                }
            }  
    
    public void syncPackageRecords(
    Map<Id, SBQQ__Quote__c> newQuoteMap,
    Map<Id, SBQQ__Quote__c> oldQuoteMap
            ) {
                if (newQuoteMap == null || newQuoteMap.isEmpty()) return;
            
                try {
                    // 1) Collect Quote Ids
                    Set<Id> quoteIds = new Set<Id>(newQuoteMap.keySet());
            
                    // 2) Get only user-added QLGs that need a package
                    List<SBQQ__QuoteLineGroup__c> qlgs = [
                        SELECT Id, Name, Installation_Quantity__c, Number_of_Rapid_Titles__c,
                               Number_of_Special_Products__c, Number_of_Virtual_Classrooms__c,
                               User_Quantity__c, CurrencyISOCode, SBQQ__Quote__c, Package__c,
                               Created_From_Package__c
                        FROM SBQQ__QuoteLineGroup__c
                        WHERE SBQQ__Quote__c IN :quoteIds
                          AND Created_From_Package__c = false
                          AND Package__c = NULL
                    ];
                    if (qlgs.isEmpty()) return;
            
                    // 3) Skip any QLGs that already have a package record
                    Set<Id> qlgIds = new Set<Id>();
                    for (SBQQ__QuoteLineGroup__c qlg : qlgs) qlgIds.add(qlg.Id);
            
                    Set<Id> qlgsWithExistingPackage = new Set<Id>();
                    for (Package__c pkg : [
                        SELECT Id, Quote_Line_Group__c
                        FROM Package__c
                        WHERE Quote_Line_Group__c IN :qlgIds
                    ]) {
                        qlgsWithExistingPackage.add((Id)pkg.Quote_Line_Group__c);
                    }
            
                    // 4) Build packages to create
                    List<Package__c> packagesToCreate = new List<Package__c>();
                    for (SBQQ__QuoteLineGroup__c qlg : qlgs) {
                        if (qlgsWithExistingPackage.contains(qlg.Id)) continue;
            
                        SBQQ__Quote__c quote = newQuoteMap.get(qlg.SBQQ__Quote__c);
                        if (quote == null) continue;
            
                        packagesToCreate.add(new Package__c(
                            Account__c                      = quote.SBQQ__Account__c,
                            Contract__c                     = quote.SBQQ__MasterContract__c,
                            Installation_Quantity__c        = qlg.Installation_Quantity__c,
                            Number_of_Rapid_Titles__c       = qlg.Number_of_Rapid_Titles__c,
                            Number_of_Special_Products__c   = qlg.Number_of_Special_Products__c,
                            Number_of_Virtual_Classrooms__c = qlg.Number_of_Virtual_Classrooms__c,
                            Package_Name__c                 = qlg.Name,
                            Name                            = qlg.Name,
                            CurrencyISOCode                 = qlg.CurrencyISOCode,
                            User_Quantity__c                = qlg.User_Quantity__c,
                            Quote__c                        = qlg.SBQQ__Quote__c,
                            Quote_Line_Group__c             = qlg.Id,
                            Temp_Quote_Line_Group__c		= qlg.Id,
                            Temp_Quote__c					= qlg.SBQQ__Quote__c
                        ));
                    }
                    if (packagesToCreate.isEmpty()) return;
            
                    // 5) Insert all new packages at once
                    insert packagesToCreate;
            
                    // 6) Link QLGs back to their packages
                    List<SBQQ__QuoteLineGroup__c> qlgUpdates = new List<SBQQ__QuoteLineGroup__c>();
                    for (Package__c p : packagesToCreate) {
                        qlgUpdates.add(new SBQQ__QuoteLineGroup__c(
                            Id = (Id)p.Quote_Line_Group__c,
                            Package__c = p.Id
                        ));
                    }
                    if (!qlgUpdates.isEmpty()) update qlgUpdates;
            
                } catch (Exception e) {
                    Logger.error(
                        'syncPackageRecords failed: ' + e.getMessage() +
                        ' | line: ' + e.getLineNumber() +
                        ' | stack: ' + e.getStackTraceString()
                    );
                    Logger.saveLog();
                }
            }

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
            
            if (!contractIdToQuoteIdMap.isEmpty()) {
                List<Package__c> packages = [
                    SELECT Id,Temp_Quote__c , Temp_Quote_Line_Group__c , Name, CurrencyISOCode,InstallationCost__c, Prior_Installation_Quantity__c, Installation_Quantity__c, Contract__c,Number_of_Special_Products__c,User_Quantity__c,Number_of_Virtual_Classrooms__c
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
                            quoteLineGroup.Created_From_Package__c = TRUE;
                            quoteLineGroup.Installation_Price__c = packageObj.InstallationCost__c; 
                            quoteLineGroup.Prior_Installation_Quantity__c = packageObj.Installation_Quantity__c;
                            newQuoteLineGroups.add(quoteLineGroup);
                            
                            // Update Package record with new Quote ID
                            packageObj.Temp_Quote__c = quoteId;
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
                            pack.Temp_Quote_Line_Group__c = packagesToUpdateMap.get(pack).Id;
                        }
                    } catch (DmlException ex) {
                        // Log exception for further analysis
                        Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
                        Logger.saveLog();
                    }
                }
                
                if (!packagesToUpdateMap.isEmpty()) {
                    try {
                        List<Package__c> packagesToUpdate = new List<Package__c>();
                        packagesToUpdate.addAll(packagesToUpdateMap.keySet());
                        update packagesToUpdate;
                        
                    } catch (DmlException ex) {
                        // Log exception for further analysis
                        Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
                        Logger.saveLog();
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

    /**
     * Enforces: Do not allow creating Amendment Quotes if there are open Quotes or Draft Orders on the Contract.
     * Contract resolution priority:
     *  - If quote is Amendment and SBQQ__MasterContract__c present -> use it
     *  - Else if Amendment and Master Contract blank -> use Opportunity.SBQQ__AmendedContract__c
     * Non-Amendment quotes are ignored.
     */
    @TestVisible
    private static void enforceNoOpenItemsForAmendment(List<SBQQ__Quote__c> incomingQuotes) {
        if (incomingQuotes == null || incomingQuotes.isEmpty()) return;

        // Resolve contract per amendment quote
        Map<Id, Id> quoteIdToContractId = new Map<Id, Id>();
        Set<Id> oppIdsToQuery = new Set<Id>();

        for (SBQQ__Quote__c q : incomingQuotes) {
            if (q.SBQQ__Type__c == QUOTE_TYPE_AMENDMENT) {
                if (q.SBQQ__MasterContract__c != null) {
                    quoteIdToContractId.put(q.Id, q.SBQQ__MasterContract__c);
                } else if (q.SBQQ__Opportunity2__c != null) {
                    oppIdsToQuery.add(q.SBQQ__Opportunity2__c);
                }
            }
        }
        if (!oppIdsToQuery.isEmpty()) {
            Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>([
                SELECT Id, SBQQ__AmendedContract__c
                FROM Opportunity
                WHERE Id IN :oppIdsToQuery
            ]);
            for (SBQQ__Quote__c q : incomingQuotes) {
                if (q.SBQQ__Type__c == QUOTE_TYPE_AMENDMENT
                    && q.SBQQ__MasterContract__c == null
                    && q.SBQQ__Opportunity2__c != null) {
                    Opportunity o = oppMap.get(q.SBQQ__Opportunity2__c);
                    if (o != null && o.SBQQ__AmendedContract__c != null) {
                        quoteIdToContractId.put(q.Id, o.SBQQ__AmendedContract__c);
                    }
                }
            }
        }

        // Invoke validator and add errors
        for (SBQQ__Quote__c q : incomingQuotes) {
            if (q.SBQQ__Type__c != QUOTE_TYPE_AMENDMENT) continue;
            Id contrId = quoteIdToContractId.get(q.Id);
            if (contrId == null) continue;

            List<String> warnings = CreateInstallationsController.validateOpenQuotesOrders(contrId);
            if (!warnings.isEmpty()) {
                q.addError('Cannot create Amendment Quote: open Quotes or Draft Orders exist for the Contract. Details: ' + String.join(warnings, ' | '));
            }
        }
    }
}