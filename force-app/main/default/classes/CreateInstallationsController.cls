public class CreateInstallationsController
{
    // Constants for hardcoded values
    private static final String STATUS_DRAFT = 'Draft';
    private static final String STATUS_TERMINATED = 'Terminated';
    private static final String STATUS_FUTURE_TERMINATED = 'Future Terminated';
    // Centralized additional status/type constants
    private static final String STATUS_APPROVED = 'Approved';
    private static final String QUOTE_STATUS_DRAFT = 'Draft';
    private static final String QUOTE_TYPE_AMENDMENT = 'Amendment';
    private static final String QUOTE_TYPE_RENEWAL = 'Renewal';
    private static final String INSTALLATION_STATUS_TERMINATED = 'Terminated';

    // Installation start date default offset in days (consider moving to Custom Metadata)
    @TestVisible
    private static Integer DEFAULT_INSTALLATION_START_OFFSET_DAYS = 30;

    private static final Integer MAX_AMENDMENT_ATTEMPTS = 5;
    private class CPQQuoteResult {
        SBQQ__Quote__c quote;
        Boolean isSuccessful;
    }
    @AuraEnabled(cacheable=true)
    public static List<String> validateOpenQuotesOrders(Id contractId) {
        List<String> warnings = new List<String>();
        if (contractId == null) {
            return warnings;
        }

        try {
            List<SBQQ__Quote__c> openQuotes = [
                SELECT Id, Name, SBQQ__Status__c, SBQQ__Ordered__c
                FROM SBQQ__Quote__c
                WHERE SBQQ__MasterContract__c = :contractId
                  AND (SBQQ__Status__c = :QUOTE_STATUS_DRAFT
                       OR (SBQQ__Status__c = :STATUS_APPROVED AND (SBQQ__Ordered__c = false OR SBQQ__Ordered__c = null)))
            ];

            Set<Id> quoteIds = new Set<Id>();
            for (SBQQ__Quote__c quote : openQuotes) {
                warnings.add('Quote ' + quote.Name + ' (' + '/' + quote.Id + ') is ' + quote.SBQQ__Status__c + ' and must be activated.');
                quoteIds.add(quote.Id);
            }

            List<Order> draftOrders;
            if (!quoteIds.isEmpty()) {
                draftOrders = [
                    SELECT Id, Name, OrderNumber, Status, SBQQ__Quote__r.SBQQ__MasterContract__c
                    FROM Order
                    WHERE SBQQ__Quote__r.SBQQ__MasterContract__c IN :quoteIds
                      AND (Status = 'Draft' OR Status = 'Pending Implementation')
                ];
            } else {
                draftOrders = [
                    SELECT Id, Name, OrderNumber, Status, SBQQ__Quote__r.SBQQ__MasterContract__c
                    FROM Order
                    WHERE SBQQ__Quote__r.SBQQ__MasterContract__c = :contractId
                      AND (Status = 'Draft' OR Status = 'Pending Implementation')
                ];
            }

            for (Order ord : draftOrders) {
                warnings.add('Order ' + ord.OrderNumber + ' (' + '/' + ord.Id + ') is in Draft status and must be activated.');
            }
        } catch (Exception ex) {
            throw new AuraHandledException('Error validating open quotes or orders.');
        }

        return warnings;
    }

     @AuraEnabled
    public static List<Package__c> getPackages(String contrId) {
        try {
            return [
                SELECT Id, Name, Contract__c, Installation_Quantity__c 
                FROM Package__c 
                WHERE Contract__c = :contrId
            ];
        } catch (Exception ex) {
            throw new AuraHandledException('Error fetching packages.');
        }
    }
    
    @AuraEnabled
    public static String createNewInstRecord(Boolean isTerminate, String packId, String contrId, Installation__c inst, Date startDate) {
        Savepoint sp = Database.setSavepoint();
        try {
            if (!isTerminate) {
                if (inst == null) {
                    throw new AuraHandledException('Installation details are required.');
                }
                if (String.isBlank(packId) || String.isBlank(contrId)) {
                    throw new AuraHandledException('Package and Contract details are required.');
                }
            }

            if (!isTerminate) {
                List<Contract> contracts = [
                    SELECT Id, Name, CurrencyIsoCode, AccountId, 
                        (SELECT Id FROM Installations__r WHERE Vessel_Name__c = :inst.Vessel_Name__c) 
                    FROM Contract 
                    WHERE Id = :contrId 
                    LIMIT 1
                ];
                
                if (contracts.isEmpty()) {
                    throw new AuraHandledException('Contract not found for the provided Id.');
                }
                Contract contr = contracts[0];

                Package__c pack = [SELECT Id, Name, Quote__c FROM Package__c WHERE Id = :packId LIMIT 1];
                
                if (inst.Vessel_Name__c != NULL && !contr.Installations__r.isEmpty()) {
                    Database.rollback(sp);
                    return 'Duplicate_Error';
                }

                inst.Contract__c = contrId;
                inst.Contract_Customer__c = contr.AccountId;
                inst.CurrencyIsoCode = contr.CurrencyIsoCode;
                inst.Package__c = packId;
                inst.Quote__c = pack.Quote__c;
                inst.Installation_Order_Status__c = STATUS_DRAFT;
                inst.Installation_Start_Date__c = (startDate != null ? startDate : Date.today().addDays(DEFAULT_INSTALLATION_START_OFFSET_DAYS));
                inst.Auto_Installation__c = true;
                
                insert inst;
                setInstallationError(inst.Id, null);
            } else {
                if (String.isBlank(contrId) || String.isBlank(packId)) {
                    throw new AuraHandledException('Contract and Package details are required for termination.');
                }
            }

            Date effectiveStartDate = startDate != null ? startDate : Date.today().addDays(DEFAULT_INSTALLATION_START_OFFSET_DAYS);
            modifyContract(inst.Id, effectiveStartDate, contrId, inst.Package__c != null ? inst.Package__c : packId, isTerminate);

            return 'SUCCESS' + (isTerminate ? '' : ': ' + inst.Id);
        } catch (AuraHandledException ahe) {
            Database.rollback(sp);
            Logger.error('CreateInstallationsController.createNewInstRecord - ' + ahe.getMessage());
            throw ahe;
        }
    }  
    
    @AuraEnabled
    public static Boolean checkDuplicates(String contrId, String vesId, String orgId)
    {
        try
        {
            List<Installation__c> instList;
            if(vesId != NULL && vesId != '')
            {
                instList = [SELECT Id, Name, Vessel_Name__c, Organisation_Name__c FROM Installation__c WHERE Vessel_Name__c = :vesId AND Contract__c = :contrId];
            }
            else
            {
                instList = [SELECT Id, Name, Vessel_Name__c, Organisation_Name__c FROM Installation__c WHERE Organisation_Name__c = :orgId AND Contract__c = :contrId];
            }
            if(!instList.isEmpty())
            {
                return TRUE;
            }
            else
            {
                return FALSE;
            }
        }
        catch (Exception ex)
        {
            throw new AuraHandledException(ex.getMessage());
        }
    }
    
    @AuraEnabled
    public static string terminateSingleRecord(String instId, Date endDate, String reason)
    {
        return terminateRecords(new List<String>{instId}, endDate, reason);
    }
    
    @AuraEnabled
    public static string terminateRecords(List<String> instIdList, Date endDate, String reason) {
        Savepoint sp = Database.setSavepoint();
        try {
            // Fetch contract dates for validation
            if (instIdList == null || instIdList.isEmpty()) {
                throw new AuraHandledException('No installations were provided for termination.');
            }

            List<Installation__c> existingInstalls = [
                SELECT Id, Contract__c, Package__c
                FROM Installation__c
                WHERE Id IN :instIdList
            ];

            if (existingInstalls.isEmpty()) {
                throw new AuraHandledException('Installation not found for termination.');
            }
            Id contractId = existingInstalls[0].Contract__c;
            if (contractId == null) {
                throw new AuraHandledException('Installation has no related contract.');
            }
            List<Contract> contractRecords = [SELECT StartDate, EndDate FROM Contract WHERE Id = :contractId LIMIT 1];
            if (contractRecords.isEmpty()) {
                throw new AuraHandledException('Contract not found for termination processing.');
            }
            Contract contr = contractRecords[0];
            for (Installation__c existingInst : existingInstalls) {
                if (existingInst.Contract__c != contractId) {
                    throw new AuraHandledException('All installations must belong to the same contract for termination.');
                }
            }

            // Validate termination date
            if (endDate < contr.StartDate || endDate > contr.EndDate) {
                throw new AuraHandledException('Termination date should be within the contracting period.');
            }

            List<Installation__c> instList = new List<Installation__c>();
            for (Installation__c existingInst : existingInstalls) {
                instList.add(new Installation__c(
                    Id = existingInst.Id,
                    Installation_Order_Status__c = endDate > Date.today() ? STATUS_FUTURE_TERMINATED : STATUS_TERMINATED,
                    Termination_End_Date__c = endDate,
                    Termination_Reason__c = reason,
                    Auto_Termination__c = true
                ));
            }

            if (!instList.isEmpty()) {
                update instList;
            }
            for (Installation__c updatedInst : instList) {
                setInstallationError(updatedInst.Id, null);
            }
            if (endDate <= Date.today()) {
                for (Installation__c existingInst : existingInstalls) {
                    if (existingInst.Package__c != null) {
                        modifyContract(existingInst.Id, endDate, contractId, existingInst.Package__c, true);
                    }
                }
            }
            return 'SUCCESS';
        } catch (AuraHandledException ahe) {
            Database.rollback(sp);
            Logger.error('Error in terminateRecords: ' + ahe.getMessage());
            throw ahe;
        } catch (Exception ex) {
            Database.rollback(sp);
            throw new AuraHandledException('Error terminating records.');
        }
    }
    
    @future(callout=true)
    public static void modifyContract(Id instId, Date startDate, Id contrId, Id packId, Boolean isTerminate) {
        try {
            Date effectiveStart = startDate != null ? startDate : Date.today();

            CPQQuoteResult cpqResult = extractCPQServiceCall(contrId);
            if (cpqResult == null || cpqResult.quote == null || !cpqResult.isSuccessful) {
                setInstallationError(instId, 'Awaiting amendment quote creation (retry 0)');
                System.enqueueJob(new AmendmentPostProcessorQueueable(instId, contrId, packId, null, effectiveStart, isTerminate, 1));
                return;
            }

            Boolean success = tryUpdateQuoteAndInstallation(cpqResult.quote, instId, contrId, packId, effectiveStart, isTerminate);
            if (!success) {
                setInstallationError(instId, 'Awaiting amendment quote line group (retry 0)');
                System.enqueueJob(new AmendmentPostProcessorQueueable(instId, contrId, packId, cpqResult.quote.Id, effectiveStart, isTerminate, 1));
            } else {
                setInstallationError(instId, null);
            }
        } catch (Exception ex) {
            setInstallationError(instId, ex.getMessage());
        }
    }
    
    private static CPQQuoteResult extractCPQServiceCall(Id contrId) {
        CPQQuoteResult result = new CPQQuoteResult();
        String quoteId = null;
        try {
            ContractAmenderHelper helper = new ContractAmenderHelper();
            ContractAmenderHelper.QuoteModel quoteModel = helper.load(contrId, true);
            if (quoteModel != null) {
                quoteId = quoteModel.Id;
            }
        } catch (Exception ex) {
            Logger.error('CreateInstallationsController.extractCPQServiceCall - CPQ helper failed: ' + ex.getMessage());
        }

        try {
            if (String.isBlank(quoteId)) {
                Logger.warn('CreateInstallationsController.extractCPQServiceCall - Quote Id not returned, falling back to latest quote on contract.');
                List<SBQQ__Quote__c> fallbackQuotes = [
                    SELECT Id, Name, SBQQ__Status__c, SBQQ__Opportunity2__c, SBQQ__Ordered__c, SBQQ__StartDate__c
                    FROM SBQQ__Quote__c
                    WHERE SBQQ__MasterContract__c = :contrId
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
                if (!fallbackQuotes.isEmpty()) {
                    result.quote = fallbackQuotes[0];
                    result.isSuccessful = true;
                    return result;
                }
            } else {
                List<SBQQ__Quote__c> quotes = [
                    SELECT Id, Name, SBQQ__Status__c, SBQQ__Opportunity2__c, SBQQ__Ordered__c, SBQQ__StartDate__c
                    FROM SBQQ__Quote__c
                    WHERE Id = :quoteId
                    LIMIT 1
                ];
                if (!quotes.isEmpty()) {
                    result.quote = quotes[0];
                    result.isSuccessful = true;
                    return result;
                }
            }
        } catch (Exception ex) {
            Logger.error('CreateInstallationsController.extractCPQServiceCall - Quote lookup failed: ' + ex.getMessage());
        }

        result.quote = null;
        result.isSuccessful = false;
        return result;
    }



    @TestVisible
    static Boolean tryUpdateQuoteAndInstallation(SBQQ__Quote__c qt, Id instId, Id contractId, Id packId, Date effectiveStart, Boolean isTerminate) {
        SBQQ__QuoteLineGroup__c qlg = null;
        try {
            qlg = [SELECT Id, Name, Installation_Quantity__c FROM SBQQ__QuoteLineGroup__c WHERE Package__c = :packId AND SBQQ__Quote__c = :qt.Id LIMIT 1];
        } catch (Exception ex) {
            Logger.warn('Quote line group not found for package ' + packId + ' quote ' + qt.Id + ': ' + ex.getMessage());
        }

        if (qlg == null) {
            return false;
        }

        Decimal qlgNewInstallationQuantity = (qlg.Installation_Quantity__c != null ? qlg.Installation_Quantity__c : 0) + (isTerminate ? -1 : 1);
        qlg.Installation_Quantity__c = qlgNewInstallationQuantity;
        try {
            update qlg;
        } catch (Exception ex) {
        }

        try {
            updateQuote(qt, instId, effectiveStart, isTerminate);
        } catch (AuraHandledException ahe) {
            setInstallationError(instId, ahe.getMessage());
            return false;
        }

        if (qt.SBQQ__Opportunity2__c != null) {
            try {
                Opportunity opp = [
                    SELECT Id, Name, StageName, Sales_Type__c, Agreement_Type__c, Existing_Opportunity_Type__c,
                           Contract_Term__c, Description, NextStep, Product_Group__c, Contact_Name__c,
                           SBQQ__AmendedContract__c,
                           SBQQ__AmendedContract__r.ContractTerm,
                           SBQQ__AmendedContract__r.Agreement_Type__c,
                           SBQQ__AmendedContract__r.SBQQ__Opportunity__c,
                           SBQQ__AmendedContract__r.SBQQ__Opportunity__r.Sales_Type__c,
                           SBQQ__AmendedContract__r.SBQQ__Opportunity__r.Product_Group__c,
                           SBQQ__AmendedContract__r.SBQQ__Opportunity__r.Contact_Name__c
                    FROM Opportunity
                    WHERE Id = :qt.SBQQ__Opportunity2__c
                    LIMIT 1
                ];

                if (opp.SBQQ__AmendedContract__c != null) {
                    opp.Existing_Opportunity_Type__c = 'Account Growth';
                    opp.Contract_Term__c = String.valueOf(opp.SBQQ__AmendedContract__r.ContractTerm);
                    opp.Description = (isTerminate ? 'Amendment - Auto Termination' : 'Amendment - Auto Installation');
                    opp.NextStep = (isTerminate ? 'Amendment - Auto Termination' : 'Amendment - Auto Installation');
                    if (opp.SBQQ__AmendedContract__r.SBQQ__Opportunity__c != null) {
                        opp.Product_Group__c = opp.SBQQ__AmendedContract__r.SBQQ__Opportunity__r.Product_Group__c;
                        opp.Contact_Name__c = opp.SBQQ__AmendedContract__r.SBQQ__Opportunity__r.Contact_Name__c;
                        opp.Sales_Type__c = opp.SBQQ__AmendedContract__r.SBQQ__Opportunity__r.Sales_Type__c;
                    }
                    update opp;
                }
            } catch (Exception ex) {
            }
        }

        if (!isTerminate) {
            Installation__c instUpdate = new Installation__c();
            instUpdate.Id = instId;
            instUpdate.Quote__c = qt.Id;
            instUpdate.Quote_Line_Group__c = qlg.Id;
            instUpdate.Auto_Installation__c = TRUE;

            try {
                update instUpdate;
            } catch (Exception ex) {
            }
        }

        return true;
    }

    public class AmendmentPostProcessorQueueable implements Queueable, Database.AllowsCallouts {
        private final Id installationId;
        private final Id contractId;
        private final Id packageId;
        private final Id quoteId;
        private final Date effectiveDate;
        private final Boolean isTerminate;
        private final Integer attempt;

        public AmendmentPostProcessorQueueable(Id installationId, Id contractId, Id packageId, Id quoteId, Date effectiveDate, Boolean isTerminate, Integer attempt) {
            this.installationId = installationId;
            this.contractId = contractId;
            this.packageId = packageId;
            this.quoteId = quoteId;
            this.effectiveDate = effectiveDate;
            this.isTerminate = isTerminate;
            this.attempt = attempt == null ? 1 : attempt;
        }

        public void execute(QueueableContext context) {
            try {
                Id localQuoteId = quoteId;
                SBQQ__Quote__c qt = null;

                if (localQuoteId != null) {
                    List<SBQQ__Quote__c> quoted = [
                        SELECT Id, Name, SBQQ__Opportunity2__c, SBQQ__Ordered__c, SBQQ__StartDate__c
                        FROM SBQQ__Quote__c
                        WHERE Id = :localQuoteId
                        LIMIT 1
                    ];
                    if (!quoted.isEmpty()) {
                        qt = quoted[0];
                    }
                }

                if (qt == null) {
                    CPQQuoteResult cpqResult = extractCPQServiceCall(contractId);
                    if (cpqResult != null && cpqResult.quote != null && cpqResult.isSuccessful) {
                        qt = cpqResult.quote;
                        localQuoteId = qt.Id;
                    }
                }

                if (qt == null) {
                    if (attempt < MAX_AMENDMENT_ATTEMPTS) {
                        setInstallationError(installationId, 'Awaiting amendment quote creation (retry ' + String.valueOf(attempt) + ')');
                        System.enqueueJob(new AmendmentPostProcessorQueueable(installationId, contractId, packageId, localQuoteId, effectiveDate, isTerminate, attempt + 1));
                    } else {
                        setInstallationError(installationId, 'Unable to create amendment quote. Please resolve any open CPQ issues and try again.');
                    }
                    return;
                }

                Boolean success = tryUpdateQuoteAndInstallation(qt, installationId, contractId, packageId, effectiveDate != null ? effectiveDate : Date.today(), isTerminate);
                if (success) {
                    setInstallationError(installationId, null);
                    return;
                }

                if (attempt < MAX_AMENDMENT_ATTEMPTS) {
                    setInstallationError(installationId, 'Awaiting amendment quote line group (retry ' + String.valueOf(attempt) + ')');
                    System.enqueueJob(new AmendmentPostProcessorQueueable(installationId, contractId, packageId, qt.Id, effectiveDate, isTerminate, attempt + 1));
                } else {
                    setInstallationError(installationId, 'Unable to update amendment quote. Quote line group is not available yet. Please retry manually.');
                }
            } catch (Exception ex) {
                setInstallationError(installationId, ex.getMessage());
            }
        }
    }

    private static void setInstallationError(Id installationId, String message) {
        if (installationId == null) {
            return;
        }
        update new Installation__c(
            Id = installationId,
            Auto_Installation_Termination_Error__c = message
        );
    }
    
    // Extracted method for quote line group handling
    @TestVisible
    private static SBQQ__QuoteLineGroup__c updateQuoteLineGroup(SBQQ__Quote__c qt, Id packId, Boolean isTerminate) {
        List<SBQQ__QuoteLineGroup__c> qlgList = [
            SELECT Id, Name, Installation_Quantity__c
            FROM SBQQ__QuoteLineGroup__c
            WHERE Package__c = :packId AND SBQQ__Quote__c = :qt.Id
            LIMIT 1
        ];

        if (qlgList.isEmpty()) {
            Logger.warn('CreateInstallationsController.updateQuoteLineGroup - No quote line group found for package ' + packId);
            return null;
        }

        return qlgList[0];
    }
    
    // Extracted method for quote updates
    @TestVisible
    private static void updateQuote(SBQQ__Quote__c qt, Id instId, Date startDate, Boolean isTerminate) {
        if (isTerminate) {
            qt.Auto_Termination__c = TRUE;
            qt.Installation__c = instId;
            List<Installation__c> inst = [
                SELECT Id, Termination_End_Date__c, Contract__r.EndDate, Contract__r.Billing_Frequency__c
                FROM Installation__c
                WHERE Id = :instId
                LIMIT 1
            ];

            if (inst.isEmpty()) {
                throw new AuraHandledException('Installation not found for termination update.');
            }

            qt.SBQQ__StartDate__c = inst[0].Termination_End_Date__c;
            qt.SBQQ__EndDate__c = inst[0].Contract__r.EndDate;
            qt.SBQQ__BillingFrequency__c = inst[0].Contract__r.Billing_Frequency__c;
        } else {
            qt.Auto_Installation__c = TRUE;
            qt.Installation__c = instId;
            qt.SBQQ__StartDate__c = startDate;
        }
        
        try {
            update qt;
        } catch (Exception ex) {
            throw new AuraHandledException('Unable to update quote: ' + ex.getMessage());
        }
    }
    
    // Extracted method for installation updates (without opportunity updates as requested)
    @TestVisible
    private static void updateInstallation(Id instId, Id quoteId, Id qlgId) {
        Installation__c inst = new Installation__c();
        inst.Id = instId;
        inst.Quote__c = quoteId;
        inst.Quote_Line_Group__c = qlgId;

        if (instId == null) {
            throw new AuraHandledException('Installation id is required for update.');
        }
        
        try {
            update inst;
        } catch (Exception ex) {
            throw new AuraHandledException('Unable to update installation: ' + ex.getMessage());
        }
    }
    
    @AuraEnabled
    public static List<InstallationData> getInstallations(String contrId)
    {
        try
        {
            List<InstallationData> instDataList = new List<InstallationData>();
            for(Installation__c inst : [SELECT Id, Name, Invoice_Account__c, Contract_Customer__c, Contract_Customer__r.Name, Installation_Order_Status__c, Installation_Start_date__c, Installation_End_date__c, Vessel_IMO__c, Vessel_Status__c, Invoice_Account__r.Name, Vessel_Name__c, Vessel_Name__r.Name, Contract__c, Contract__r.Name FROM Installation__c WHERE Contract__c = :contrId AND Installation_Order_Status__c != :INSTALLATION_STATUS_TERMINATED])
            {
                InstallationData instData = new InstallationData();
                instData.InstId = inst.Id;
                instData.InstUrl = '/' + inst.Id;
                instData.InstName = inst.Name;
                instData.VesselName = inst.Vessel_Name__r.Name;
                instData.VesselIMO = inst.Vessel_IMO__c;
                instData.VesselStatus = inst.Vessel_Status__c;
                instData.InstStatus = inst.Installation_Order_Status__c;
                instData.startDate = inst.Installation_Start_Date__c;
                instData.endDate = inst.Installation_End_date__c;
                instData.CustContractName = inst.Contract_Customer__r.Name;
                instData.CustContractId = inst.Contract_Customer__c;
                instData.CustContractUrl = '/' + inst.Contract_Customer__c;
                instDataList.add(instData);
            }
            return instDataList;
        }
        catch (Exception ex)
        {
            throw new AuraHandledException(ex.getMessage());
        }
    }
    
    @AuraEnabled
    public static List<Installation__c> getInstallationRecs(String contrId)
    {
        try
        {
            return [SELECT Id, Name, Invoice_Account__c, Invoice_Account__r.Name, Vessel_Name__c, Vessel_Name__r.Name, Contract__c, Contract__r.Name FROM Installation__c WHERE Contract__c = :contrId AND Installation_Order_Status__c != :INSTALLATION_STATUS_TERMINATED];
        }
        catch (Exception ex)
        {
            throw new AuraHandledException(ex.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getContractDetails(Id recordId) {
        Map<String, Object> contractDetails = new Map<String, Object>();
    
        Installation__c installation = [
            SELECT Contract__r.StartDate, Contract__r.EndDate, Contract__r.Status
            FROM Installation__c
            WHERE Id = :recordId
            LIMIT 1
        ];
    
        if (installation.Contract__r != null) {
            contractDetails.put('startDate', installation.Contract__r.StartDate);
            contractDetails.put('endDate', installation.Contract__r.EndDate);
            contractDetails.put('status', installation.Contract__r.Status);
        }
    
        return contractDetails;
    }
    
    public class InstallationData
    {
        @AuraEnabled
        public String InstId;
        @AuraEnabled
        public String InstUrl;
        @AuraEnabled
        public String InstName;
        @AuraEnabled
        public String VesselName;
        @AuraEnabled
        public String VesselIMO;
        @AuraEnabled
        public String VesselStatus;
        @AuraEnabled
        public String InstStatus;
        @AuraEnabled
        public String CustContractId;
        @AuraEnabled
        public String CustContractUrl;
        @AuraEnabled
        public String CustContractName;
        @AuraEnabled
        public Date startDate;
        @AuraEnabled
        public Date endDate;
    }
}