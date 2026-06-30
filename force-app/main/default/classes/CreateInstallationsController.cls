public class CreateInstallationsController
{
    // Constants for hardcoded values
    private static final String STATUS_DRAFT = 'Draft';
    private static final String STATUS_TERMINATED = 'Terminated';
    private static final String STATUS_FUTURE_TERMINATED = 'Future Terminated';
    private static final String STATUS_TERMINATION_PENDING = 'Termination Pending';
    private static final String PROCESS_STATUS_REQUESTED = 'Requested';
    private static final String PROCESS_STATUS_SO_UPDATED = 'SO Updated';
    private static final String PROCESS_STATUS_CPQ_SUBMITTED = 'CPQ Submitted';
    private static final String PROCESS_STATUS_WAITING_FOR_ORDER = 'Waiting For Order Activation';
    private static final String PROCESS_STATUS_COMPLETED = 'Completed';
    private static final String PROCESS_STATUS_FAILED = 'Failed';
    private static final String PROCESS_STATUS_RETRY_PENDING = 'Retry Pending';
    // Centralized additional status/type constants
    private static final String STATUS_APPROVED = 'Approved';
    private static final String QUOTE_STATUS_DRAFT = 'Draft';
    private static final String QUOTE_TYPE_AMENDMENT = 'Amendment';
    private static final String QUOTE_TYPE_RENEWAL = 'Renewal';
    private static final String INSTALLATION_STATUS_TERMINATED = 'Terminated';

    // Installation start date default offset in days (consider moving to Custom Metadata)
    @TestVisible
    private static Integer DEFAULT_INSTALLATION_START_OFFSET_DAYS = 30;

    private static final Integer MAX_AMENDMENT_ATTEMPTS = 6;
    private static final Integer AMENDMENT_RETRY_DELAY_MINUTES = 3;
    private static final Integer TERMINATION_QUOTE_LOOKBACK_SECONDS = 5;
    @TestVisible
    private static Boolean TEST_FORCE_FIND_QUOTE_MASTER_ERROR = false;
    @TestVisible
    private static Boolean TEST_FORCE_FIND_QUOTE_AMENDED_ERROR = false;
    private class CPQQuoteResult {
        SBQQ__Quote__c quote;
        Boolean isSuccessful;
        String errorMessage;
    }
    private class AmendmentSyncResult {
        Boolean isSuccessful;
        Boolean shouldRetry;
        String errorMessage;
        Id quoteId;
        Id quoteLineGroupId;
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
                      AND Type != 'Service Delivery'
                ];
            } else {
                draftOrders = [
                    SELECT Id, Name, OrderNumber, Status, SBQQ__Quote__r.SBQQ__MasterContract__c
                    FROM Order
                    WHERE SBQQ__Quote__r.SBQQ__MasterContract__c = :contractId
                      AND (Status = 'Draft' OR Status = 'Pending Implementation')
                      AND Type != 'Service Delivery'
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
                    SELECT Id, Name, CurrencyIsoCode, AccountId
                    FROM Contract 
                    WHERE Id = :contrId 
                    LIMIT 1
                ];
                
                if (contracts.isEmpty()) {
                    throw new AuraHandledException('Contract not found for the provided Id.');
                }
                Contract contr = contracts[0];

                Package__c pack = [SELECT Id, Name, Quote__c FROM Package__c WHERE Id = :packId LIMIT 1];
                
                if (hasDuplicateInstallation(contrId, inst.Vessel_Name__c, inst.Organisation_Name__c)) {
                    Database.rollback(sp);
                    return 'Duplicate_Error';
                }

                inst.Contract__c = contrId;
                inst.Contract_Customer__c = contr.AccountId;
                inst.CurrencyIsoCode = contr.CurrencyIsoCode;
                inst.Package__c = packId;
                inst.Quote__c = pack.Quote__c;
                inst.Installation_Order_Status__c = STATUS_DRAFT;
                inst.Auto_Installation__c = true;
                
                insert inst;
                setInstallationError(inst.Id, null);
            } else {
                if (String.isBlank(contrId) || String.isBlank(packId)) {
                    throw new AuraHandledException('Contract and Package details are required for termination.');
                }
            }

            Date effectiveStartDate = startDate != null ? startDate : Date.today();
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
            return hasDuplicateInstallation(contrId, vesId, orgId);
        }
        catch (Exception ex)
        {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    private static Boolean hasDuplicateInstallation(String contrId, String vesId, String orgId) {
        if (String.isBlank(contrId)) {
            return false;
        }

        if (!String.isBlank(vesId)) {
            String vesselImo;
            try {
                Vessel__c vessel = [
                    SELECT Vessel_IMO__c
                    FROM Vessel__c
                    WHERE Id = :vesId
                    LIMIT 1
                ];
                vesselImo = vessel.Vessel_IMO__c;
            } catch (Exception ex) {
                vesselImo = null;
            }

            List<Installation__c> matchingInstallations = String.isBlank(vesselImo)
                ? [
                    SELECT Id
                    FROM Installation__c
                    WHERE Contract__c = :contrId
                      AND Vessel_Name__c = :vesId
                      AND Installation_Order_Status__c != :STATUS_TERMINATED
                    LIMIT 1
                ]
                : [
                    SELECT Id
                    FROM Installation__c
                    WHERE Contract__c = :contrId
                      AND (Vessel_Name__c = :vesId OR Vessel_IMO__c = :vesselImo)
                      AND Installation_Order_Status__c != :STATUS_TERMINATED
                    LIMIT 1
                ];
            return !matchingInstallations.isEmpty();
        }

        if (!String.isBlank(orgId)) {
            return ![
                SELECT Id
                FROM Installation__c
                WHERE Contract__c = :contrId
                  AND Organisation_Name__c = :orgId
                  AND Installation_Order_Status__c != :STATUS_TERMINATED
                LIMIT 1
            ].isEmpty();
        }

        return false;
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
                    Installation_Order_Status__c = endDate > Date.today() ? STATUS_FUTURE_TERMINATED : STATUS_TERMINATION_PENDING,
                    Termination_End_Date__c = endDate,
                    Termination_Reason__c = reason,
                    Auto_Termination__c = true,
                    Termination_Quote__c = null,
                    Termination_Order__c = null,
                    Termination_Process_Status__c = PROCESS_STATUS_REQUESTED,
                    Termination_Process_Error__c = null
                ));
            }

            if (!instList.isEmpty()) {
                update instList;
            }
            for (Installation__c updatedInst : instList) {
                setInstallationError(updatedInst.Id, null);
            }
            if (endDate <= Date.today()) {
                String terminationRequestMarker = formatRequestMarker(System.now());
                for (Installation__c existingInst : existingInstalls) {
                    if (existingInst.Package__c != null) {
                        modifyContract(existingInst.Id, endDate, contractId, existingInst.Package__c, true, terminationRequestMarker);
                    } else {
                        markTerminationFailed(
                            existingInst.Id,
                            'Termination cannot proceed because the installation has no related package.'
                        );
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
    
    public static void modifyContract(Id instId, Date startDate, Id contrId, Id packId, Boolean isTerminate) {
        modifyContract(instId, startDate, contrId, packId, isTerminate, null);
    }

    @future(callout=true)
    public static void modifyContract(Id instId, Date startDate, Id contrId, Id packId, Boolean isTerminate, String requestMarker) {
        try {
            Date effectiveStart = startDate != null ? startDate : Date.today();
            CPQQuoteResult cpqResult = extractCPQServiceCall(contrId, instId, isTerminate, requestMarker);
            if (cpqResult == null || cpqResult.quote == null || !cpqResult.isSuccessful) {
                if (isTerminate) {
                    setTerminationRetryState(instId, null, buildAwaitingQuoteCreationMessage(0, cpqResult));
                } else {
                    setInstallationError(instId, buildAwaitingQuoteCreationMessage(0, cpqResult));
                }
                enqueueAmendmentPostProcessor(instId, contrId, packId, null, effectiveStart, isTerminate, 1, requestMarker);
                return;
            }

            AmendmentSyncResult syncResult = syncQuoteAndInstallation(cpqResult.quote, instId, contrId, packId, effectiveStart, isTerminate);
            if (!syncResult.isSuccessful) {
                if (syncResult.shouldRetry) {
                    if (isTerminate) {
                        setTerminationRetryState(instId, cpqResult.quote.Id, 'Awaiting amendment quote line group (retry 0)');
                    } else {
                        setInstallationError(instId, 'Awaiting amendment quote line group (retry 0)');
                    }
                    enqueueAmendmentPostProcessor(instId, contrId, packId, cpqResult.quote.Id, effectiveStart, isTerminate, 1, requestMarker);
                } else if (isTerminate) {
                    markTerminationFailed(instId, syncResult.errorMessage);
                } else {
                    setInstallationError(instId, syncResult.errorMessage);
                }
            } else {
                setInstallationError(instId, null);
            }
        } catch (Exception ex) {
            if (isTerminate) {
                markTerminationFailed(instId, ex.getMessage());
            } else {
                setInstallationError(instId, ex.getMessage());
            }
        }
    }
    
    private static CPQQuoteResult extractCPQServiceCall(Id contrId, Id instId, Boolean isTerminate, String requestMarker) {
        CPQQuoteResult result = new CPQQuoteResult();
        if (contrId == null) {
            Logger.error('CreateInstallationsController.extractCPQServiceCall - Contract Id is null.');
            result.quote = null;
            result.isSuccessful = false;
            return result;
        }

        String quoteId = null;
        try {
            ContractAmenderHelper helper = new ContractAmenderHelper();
            ContractAmenderHelper.QuoteModel quoteModel = helper.load(contrId, true);
            if (quoteModel != null) {
                quoteId = quoteModel.Id;
                Logger.info('CreateInstallationsController.extractCPQServiceCall - CPQ helper returned quoteId=' + quoteId + ' for contractId=' + contrId);
            } else {
                Logger.warn('CreateInstallationsController.extractCPQServiceCall - CPQ helper returned null quote model for contractId=' + contrId);
            }
        } catch (Exception ex) {
            result.errorMessage = 'CPQ amendment request failed: ' + ex.getMessage();
            Logger.error(
                'CreateInstallationsController.extractCPQServiceCall - CPQ helper failed for contractId=' + contrId +
                ' with message=' + ex.getMessage() +
                ' stack=' + ex.getStackTraceString()
            );
        }

        try {
            if (String.isBlank(quoteId)) {
                Logger.warn('CreateInstallationsController.extractCPQServiceCall - Quote Id not returned for contractId=' + contrId + ', using fallback lookup.');
                SBQQ__Quote__c fallbackQuote = isTerminate
                    ? findTerminationQuoteForRequest(contrId, instId, requestMarker, 'extract_fallback')
                    : findLatestQuoteForContract(contrId, 'extract_fallback');
                if (fallbackQuote != null) {
                    result.quote = fallbackQuote;
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
                    Logger.info('CreateInstallationsController.extractCPQServiceCall - Quote loaded by helper id. quoteId=' + result.quote.Id + ' contractId=' + contrId);
                    return result;
                }
            }
        } catch (Exception ex) {
            Logger.error(
                'CreateInstallationsController.extractCPQServiceCall - Quote lookup failed for contractId=' + contrId +
                ' with message=' + ex.getMessage() +
                ' stack=' + ex.getStackTraceString()
            );
        }

        Logger.warn('CreateInstallationsController.extractCPQServiceCall - No quote found for contractId=' + contrId + ' after helper and fallback lookups.');
        result.quote = null;
        result.isSuccessful = false;
        return result;
    }

    @TestVisible
    private static SBQQ__Quote__c findTerminationQuoteForRequest(Id contrId, Id instId, String requestMarker, String contextLabel) {
        if (contrId == null || instId == null) {
            Logger.warn('CreateInstallationsController.findTerminationQuoteForRequest - Missing contract or installation. context=' + contextLabel);
            return null;
        }

        Datetime createdAfter = parseRequestMarker(requestMarker);
        if (createdAfter == null) {
            Logger.warn('CreateInstallationsController.findTerminationQuoteForRequest - Request marker missing or invalid. context=' + contextLabel);
            return null;
        }

        Datetime lookbackStart = createdAfter.addSeconds(-TERMINATION_QUOTE_LOOKBACK_SECONDS);
        try {
            List<SBQQ__Quote__c> linkedQuotes = [
                SELECT Id, Name, SBQQ__Status__c, SBQQ__Opportunity2__c, SBQQ__Ordered__c, SBQQ__StartDate__c
                FROM SBQQ__Quote__c
                WHERE SBQQ__Type__c = :QUOTE_TYPE_AMENDMENT
                  AND Installation__c = :instId
                  AND Auto_Termination__c = true
                  AND CreatedDate >= :lookbackStart
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!linkedQuotes.isEmpty()) {
                Logger.info(
                    'CreateInstallationsController.findTerminationQuoteForRequest - Found linked termination quote. quoteId=' +
                    linkedQuotes[0].Id + ' contractId=' + contrId + ' installationId=' + instId + ' context=' + contextLabel
                );
                return linkedQuotes[0];
            }
        } catch (Exception ex) {
            Logger.error(
                'CreateInstallationsController.findTerminationQuoteForRequest - Linked quote lookup failed for contractId=' + contrId +
                ' installationId=' + instId + ' context=' + contextLabel + ' message=' + ex.getMessage()
            );
        }

        try {
            List<SBQQ__Quote__c> candidateQuotes = [
                SELECT Id, Name, SBQQ__Status__c, SBQQ__Opportunity2__c, SBQQ__Ordered__c, SBQQ__StartDate__c
                FROM SBQQ__Quote__c
                WHERE SBQQ__Type__c = :QUOTE_TYPE_AMENDMENT
                  AND (
                      SBQQ__MasterContract__c = :contrId
                      OR SBQQ__Opportunity2__r.SBQQ__AmendedContract__c = :contrId
                  )
                  AND CreatedDate >= :lookbackStart
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!candidateQuotes.isEmpty()) {
                Logger.info(
                    'CreateInstallationsController.findTerminationQuoteForRequest - Found fresh termination quote candidate. quoteId=' +
                    candidateQuotes[0].Id + ' contractId=' + contrId + ' installationId=' + instId + ' context=' + contextLabel
                );
                return candidateQuotes[0];
            }
        } catch (Exception ex) {
            Logger.error(
                'CreateInstallationsController.findTerminationQuoteForRequest - Fresh quote lookup failed for contractId=' + contrId +
                ' installationId=' + instId + ' context=' + contextLabel + ' message=' + ex.getMessage()
            );
        }

        Logger.warn(
            'CreateInstallationsController.findTerminationQuoteForRequest - No safe termination quote found for contractId=' + contrId +
            ' installationId=' + instId + ' context=' + contextLabel
        );
        return null;
    }

    @TestVisible
    private static SBQQ__Quote__c findLatestQuoteForContract(Id contrId, String contextLabel) {
        if (contrId == null) {
            Logger.warn('CreateInstallationsController.findLatestQuoteForContract - Contract Id is null. context=' + contextLabel);
            return null;
        }

        try {
            if (Test.isRunningTest() && TEST_FORCE_FIND_QUOTE_MASTER_ERROR) {
                throw new AuraHandledException('Forced master contract lookup error');
            }
            List<SBQQ__Quote__c> amendmentQuotes = [
                SELECT Id, Name, SBQQ__Status__c, SBQQ__Opportunity2__c, SBQQ__Ordered__c, SBQQ__StartDate__c
                FROM SBQQ__Quote__c
                WHERE SBQQ__Type__c = :QUOTE_TYPE_AMENDMENT
                  AND (
                      SBQQ__MasterContract__c = :contrId
                      OR SBQQ__Opportunity2__r.SBQQ__AmendedContract__c = :contrId
                  )
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!amendmentQuotes.isEmpty()) {
                Logger.info(
                    'CreateInstallationsController.findLatestQuoteForContract - Found latest amendment quote. quoteId=' +
                    amendmentQuotes[0].Id + ' contractId=' + contrId + ' context=' + contextLabel
                );
                return amendmentQuotes[0];
            }
        } catch (Exception ex) {
            Logger.error(
                'CreateInstallationsController.findLatestQuoteForContract - Amendment quote lookup failed for contractId=' + contrId +
                ' context=' + contextLabel + ' message=' + ex.getMessage()
            );
        }

        try {
            if (Test.isRunningTest() && TEST_FORCE_FIND_QUOTE_AMENDED_ERROR) {
                throw new AuraHandledException('Forced amended opportunity lookup error');
            }
            List<SBQQ__Quote__c> amendedOpportunityQuotes = [
                SELECT Id, Name, SBQQ__Status__c, SBQQ__Opportunity2__c, SBQQ__Ordered__c, SBQQ__StartDate__c
                FROM SBQQ__Quote__c
                WHERE SBQQ__Type__c = :QUOTE_TYPE_AMENDMENT
                  AND SBQQ__Opportunity2__r.SBQQ__AmendedContract__c = :contrId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!amendedOpportunityQuotes.isEmpty()) {
                Logger.info(
                    'CreateInstallationsController.findLatestQuoteForContract - Found latest quote via amended opportunity. quoteId=' +
                    amendedOpportunityQuotes[0].Id + ' contractId=' + contrId + ' context=' + contextLabel
                );
                return amendedOpportunityQuotes[0];
            }
        } catch (Exception ex) {
            Logger.error(
                'CreateInstallationsController.findLatestQuoteForContract - Amended opportunity lookup failed for contractId=' + contrId +
                ' context=' + contextLabel + ' message=' + ex.getMessage()
            );
        }

        try {
            List<SBQQ__Quote__c> masterContractQuotes = [
                SELECT Id, Name, SBQQ__Status__c, SBQQ__Opportunity2__c, SBQQ__Ordered__c, SBQQ__StartDate__c
                FROM SBQQ__Quote__c
                WHERE SBQQ__MasterContract__c = :contrId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!masterContractQuotes.isEmpty()) {
                Logger.info(
                    'CreateInstallationsController.findLatestQuoteForContract - Found latest fallback quote via master contract. quoteId=' +
                    masterContractQuotes[0].Id + ' contractId=' + contrId + ' context=' + contextLabel
                );
                return masterContractQuotes[0];
            }
        } catch (Exception ex) {
            Logger.error(
                'CreateInstallationsController.findLatestQuoteForContract - Fallback master contract lookup failed for contractId=' + contrId +
                ' context=' + contextLabel + ' message=' + ex.getMessage()
            );
        }

        Logger.warn(
            'CreateInstallationsController.findLatestQuoteForContract - No quote found for contractId=' + contrId + ' context=' + contextLabel
        );
        return null;
    }



    private static AmendmentSyncResult syncQuoteAndInstallation(SBQQ__Quote__c qt, Id instId, Id contractId, Id packId, Date effectiveStart, Boolean isTerminate) {
        AmendmentSyncResult result = new AmendmentSyncResult();
        result.isSuccessful = false;
        result.shouldRetry = false;
        result.quoteId = qt != null ? qt.Id : null;
        Savepoint sp = Database.setSavepoint();
        List<Installation__c> installationStates = [
            SELECT Id, Quote_Line_Group__c, Termination_Quote__c, Termination_Process_Status__c
            FROM Installation__c
            WHERE Id = :instId
            LIMIT 1
        ];
        if (installationStates.isEmpty()) {
            result.errorMessage = 'Installation not found for amendment processing.';
            return result;
        }
        Installation__c installationState = installationStates[0];

        try {
            // Stamp the amendment quote immediately once it exists. QLG creation can lag behind
            // quote creation in CPQ, so quote state must not depend on QLG availability.
            updateQuote(qt, instId, effectiveStart, isTerminate);
            if (isTerminate) {
                update new Installation__c(
                    Id = instId,
                    Termination_Quote__c = qt.Id,
                    Termination_Process_Status__c = PROCESS_STATUS_CPQ_SUBMITTED,
                    Termination_Process_Error__c = null
                );
            }
        } catch (Exception ex) {
            result.errorMessage = ex.getMessage();
            return result;
        }

        SBQQ__QuoteLineGroup__c qlg = null;
        try {
            qlg = [SELECT Id, Name, Installation_Quantity__c FROM SBQQ__QuoteLineGroup__c WHERE Package__c = :packId AND SBQQ__Quote__c = :qt.Id LIMIT 1];
        } catch (Exception ex) {
            Logger.warn('Quote line group not found for package ' + packId + ' quote ' + qt.Id + ': ' + ex.getMessage());
        }

        if (qlg == null) {
            result.shouldRetry = true;
            result.errorMessage = 'Awaiting amendment quote line group.';
            return result;
        }
        result.quoteLineGroupId = qlg.Id;

        Boolean terminationAlreadyTracked =
            isTerminate &&
            installationState.Termination_Quote__c == qt.Id &&
            installationState.Quote_Line_Group__c == qlg.Id &&
            (
                installationState.Termination_Process_Status__c == PROCESS_STATUS_WAITING_FOR_ORDER ||
                installationState.Termination_Process_Status__c == PROCESS_STATUS_COMPLETED
            );

        if (!terminationAlreadyTracked) {
            Decimal currentQuantity = qlg.Installation_Quantity__c != null ? qlg.Installation_Quantity__c : 0;
            Decimal quantityDelta = isTerminate ? -1 : 1;
            Decimal newQuantity = currentQuantity + quantityDelta;
            if (isTerminate && newQuantity < 0) {
                result.errorMessage = 'Termination cannot reduce amendment quote line group quantity below zero.';
                return result;
            }
            qlg.Installation_Quantity__c = newQuantity;
        }
        try {
            if (!terminationAlreadyTracked) {
                update qlg;
            }

            Installation__c instUpdate = new Installation__c();
            instUpdate.Id = instId;
            instUpdate.Quote__c = qt.Id;
            instUpdate.Quote_Line_Group__c = qlg.Id;
            if (!isTerminate) {
                instUpdate.Auto_Installation__c = TRUE;
            } else {
                instUpdate.Termination_Quote__c = qt.Id;
                instUpdate.Termination_Process_Status__c = PROCESS_STATUS_WAITING_FOR_ORDER;
                instUpdate.Termination_Process_Error__c = null;
            }
            update instUpdate;
        } catch (Exception ex) {
            Database.rollback(sp);
            result.errorMessage = ex.getMessage();
            return result;
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
                    opp.Contract_Type__c = 'Existing Contract';
                    opp.Contract_Term__c = String.valueOf(12);
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

        result.isSuccessful = true;
        result.errorMessage = null;
        return result;
    }

    @TestVisible
    static Boolean tryUpdateQuoteAndInstallation(SBQQ__Quote__c qt, Id instId, Id contractId, Id packId, Date effectiveStart, Boolean isTerminate) {
        return syncQuoteAndInstallation(qt, instId, contractId, packId, effectiveStart, isTerminate).isSuccessful;
    }

    private static void enqueueAmendmentPostProcessor(
        Id installationId,
        Id contractId,
        Id packageId,
        Id quoteId,
        Date effectiveDate,
        Boolean isTerminate,
        Integer attempt,
        String requestMarker
    ) {
        Integer delayMinutes = Test.isRunningTest() ? 0 : AMENDMENT_RETRY_DELAY_MINUTES;
        // Run the first retry immediately in a fresh async transaction so newly-created
        // amendment QLGs can be picked up without waiting for the scheduled delay.
        if (delayMinutes <= 0 || attempt == 1) {
            System.enqueueJob(new AmendmentPostProcessorQueueable(installationId, contractId, packageId, quoteId, effectiveDate, isTerminate, attempt, requestMarker));
            return;
        }

        Datetime runAt = System.now().addMinutes(delayMinutes);
        String cron = buildSingleRunCron(runAt);
        String jobName = 'AmendmentRetry_' + String.valueOf(installationId) + '_' + String.valueOf(Math.abs(Crypto.getRandomLong()));

        System.schedule(
            jobName,
            cron,
            new AmendmentPostProcessorScheduler(installationId, contractId, packageId, quoteId, effectiveDate, isTerminate, attempt, requestMarker)
        );
    }

    private static String buildSingleRunCron(Datetime runAt) {
        return String.valueOf(runAt.second()) + ' ' +
            String.valueOf(runAt.minute()) + ' ' +
            String.valueOf(runAt.hour()) + ' ' +
            String.valueOf(runAt.day()) + ' ' +
            String.valueOf(runAt.month()) + ' ? ' +
            String.valueOf(runAt.year());
    }

    public class AmendmentPostProcessorScheduler implements Schedulable, Database.AllowsCallouts {
        private final Id installationId;
        private final Id contractId;
        private final Id packageId;
        private final Id quoteId;
        private final Date effectiveDate;
        private final Boolean isTerminate;
        private final Integer attempt;
        private final String requestMarker;

        public AmendmentPostProcessorScheduler(Id installationId, Id contractId, Id packageId, Id quoteId, Date effectiveDate, Boolean isTerminate, Integer attempt) {
            this(installationId, contractId, packageId, quoteId, effectiveDate, isTerminate, attempt, null);
        }

        public AmendmentPostProcessorScheduler(Id installationId, Id contractId, Id packageId, Id quoteId, Date effectiveDate, Boolean isTerminate, Integer attempt, String requestMarker) {
            this.installationId = installationId;
            this.contractId = contractId;
            this.packageId = packageId;
            this.quoteId = quoteId;
            this.effectiveDate = effectiveDate;
            this.isTerminate = isTerminate;
            this.attempt = attempt;
            this.requestMarker = requestMarker;
        }

        public void execute(SchedulableContext context) {
            runAmendmentPostProcessor(installationId, contractId, packageId, quoteId, effectiveDate, isTerminate, attempt, requestMarker);
        }
    }

    public class AmendmentPostProcessorQueueable implements Queueable, Database.AllowsCallouts {
        private final Id installationId;
        private final Id contractId;
        private final Id packageId;
        private final Id quoteId;
        private final Date effectiveDate;
        private final Boolean isTerminate;
        private final Integer attempt;
        private final String requestMarker;

        public AmendmentPostProcessorQueueable(Id installationId, Id contractId, Id packageId, Id quoteId, Date effectiveDate, Boolean isTerminate, Integer attempt) {
            this(installationId, contractId, packageId, quoteId, effectiveDate, isTerminate, attempt, null);
        }

        public AmendmentPostProcessorQueueable(Id installationId, Id contractId, Id packageId, Id quoteId, Date effectiveDate, Boolean isTerminate, Integer attempt, String requestMarker) {
            this.installationId = installationId;
            this.contractId = contractId;
            this.packageId = packageId;
            this.quoteId = quoteId;
            this.effectiveDate = effectiveDate;
            this.isTerminate = isTerminate;
            this.attempt = attempt == null ? 1 : attempt;
            this.requestMarker = requestMarker;
        }

        public void execute(QueueableContext context) {
            runAmendmentPostProcessor(installationId, contractId, packageId, quoteId, effectiveDate, isTerminate, attempt, requestMarker);
        }
    }

    private static void runAmendmentPostProcessor(
        Id installationId,
        Id contractId,
        Id packageId,
        Id quoteId,
        Date effectiveDate,
        Boolean isTerminate,
        Integer attempt,
        String requestMarker
    ) {
        try {
            Id localQuoteId = quoteId;
            SBQQ__Quote__c qt = null;
            CPQQuoteResult cpqResult;

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
                cpqResult = extractCPQServiceCall(contractId, installationId, isTerminate, requestMarker);
                if (cpqResult != null && cpqResult.quote != null && cpqResult.isSuccessful) {
                    qt = cpqResult.quote;
                    localQuoteId = qt.Id;
                }
            }

            if (qt == null) {
                if (attempt < MAX_AMENDMENT_ATTEMPTS) {
                    String retryMessage = buildAwaitingQuoteCreationMessage(attempt, cpqResult);
                    if (isTerminate) {
                        setTerminationRetryState(installationId, null, retryMessage);
                    } else {
                        setInstallationError(installationId, retryMessage);
                    }
                    enqueueAmendmentPostProcessor(installationId, contractId, packageId, localQuoteId, effectiveDate, isTerminate, attempt + 1, requestMarker);
                } else {
                    if (isTerminate) {
                        markTerminationFailed(
                            installationId,
                            'Amendment quote was not created.'
                        );
                    } else {
                        setInstallationError(installationId, 'Unable to create amendment quote. Please resolve any open CPQ issues and try again.');
                    }
                }
                return;
            }

            AmendmentSyncResult syncResult = syncQuoteAndInstallation(
                qt,
                installationId,
                contractId,
                packageId,
                effectiveDate != null ? effectiveDate : Date.today(),
                isTerminate
            );
            if (syncResult.isSuccessful) {
                setInstallationError(installationId, null);
                return;
            }

            if (syncResult.shouldRetry && attempt < MAX_AMENDMENT_ATTEMPTS) {
                if (isTerminate) {
                    setTerminationRetryState(
                        installationId,
                        qt.Id,
                        'Awaiting amendment quote line group (retry ' + String.valueOf(attempt) + ')'
                    );
                } else {
                    setInstallationError(installationId, 'Awaiting amendment quote line group (retry ' + String.valueOf(attempt) + ')');
                }
                enqueueAmendmentPostProcessor(installationId, contractId, packageId, qt.Id, effectiveDate, isTerminate, attempt + 1, requestMarker);
            } else if (!syncResult.shouldRetry) {
                if (isTerminate) {
                    markTerminationFailed(installationId, syncResult.errorMessage);
                } else {
                    setInstallationError(installationId, syncResult.errorMessage);
                }
            } else {
                if (isTerminate) {
                    markTerminationFailed(
                        installationId,
                        'Unable to update amendment quote. Quote line group is not available yet. Please retry manually.'
                    );
                } else {
                    setInstallationError(installationId, 'Unable to update amendment quote. Quote line group is not available yet. Please retry manually.');
                }
            }
        } catch (Exception ex) {
            if (isTerminate) {
                markTerminationFailed(installationId, ex.getMessage());
            } else {
                setInstallationError(installationId, ex.getMessage());
            }
        }
    }

    private static String buildAwaitingQuoteCreationMessage(Integer attempt, CPQQuoteResult cpqResult) {
        String retryMessage = 'Awaiting amendment quote creation (retry ' + String.valueOf(attempt) + ')';
        if (cpqResult != null && String.isNotBlank(cpqResult.errorMessage)) {
            return cpqResult.errorMessage + '. ' + retryMessage;
        }
        return retryMessage;
    }

    private static void setInstallationError(Id installationId, String message) {
        if (installationId == null) {
            return;
        }
        List<Installation__c> installationStates = [
            SELECT Id, Auto_Termination__c, Termination_Process_Status__c, Termination_Quote__c, Termination_Order__c
            FROM Installation__c
            WHERE Id = :installationId
            LIMIT 1
        ];
        if (installationStates.isEmpty()) {
            return;
        }

        Installation__c installationState = installationStates[0];
        Installation__c installationUpdate = new Installation__c(
            Id = installationId,
            Auto_Installation_Termination_Error__c = message
        );
        if (
            installationState.Auto_Termination__c == true ||
            installationState.Termination_Process_Status__c != null ||
            installationState.Termination_Quote__c != null ||
            installationState.Termination_Order__c != null
        ) {
            installationUpdate.Termination_Process_Error__c = message;
        }
        update installationUpdate;
    }

    @TestVisible
    private static String formatRequestMarker(Datetime requestTime) {
        if (requestTime == null) {
            return null;
        }
        return requestTime.formatGmt('yyyy-MM-dd HH:mm:ss');
    }

    private static Datetime parseRequestMarker(String requestMarker) {
        if (String.isBlank(requestMarker)) {
            return null;
        }
        try {
            return Datetime.valueOfGmt(requestMarker);
        } catch (Exception ex) {
            Logger.warn('CreateInstallationsController.parseRequestMarker - Invalid request marker: ' + requestMarker);
            return null;
        }
    }

    private static void setTerminationRetryState(Id installationId, Id terminationQuoteId, String message) {
        if (installationId == null) {
            return;
        }
        updateTerminationTracking(
            installationId,
            PROCESS_STATUS_RETRY_PENDING,
            message,
            terminationQuoteId,
            null,
            terminationQuoteId != null,
            false
        );
    }

    private static void markTerminationFailed(Id installationId, String message) {
        if (installationId == null) {
            return;
        }
        updateTerminationTracking(installationId, PROCESS_STATUS_FAILED, message, null, null, false, false);
    }

    private static void updateTerminationTracking(
        Id installationId,
        String processStatus,
        String processError,
        Id terminationQuoteId,
        Id terminationOrderId,
        Boolean updateQuote,
        Boolean updateOrder
    ) {
        Installation__c installationUpdate = new Installation__c(
            Id = installationId,
            Auto_Installation_Termination_Error__c = processError,
            Termination_Process_Error__c = processError
        );
        if (processStatus != null) {
            installationUpdate.Termination_Process_Status__c = processStatus;
        }
        if (updateQuote) {
            installationUpdate.Termination_Quote__c = terminationQuoteId;
        }
        if (updateOrder) {
            installationUpdate.Termination_Order__c = terminationOrderId;
        }
        update installationUpdate;
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
            Set<String> excludedStatuses = new Set<String>{STATUS_TERMINATED, STATUS_FUTURE_TERMINATED, STATUS_TERMINATION_PENDING};
            List<InstallationData> instDataList = new List<InstallationData>();
            for(Installation__c inst : [SELECT Id, Name, Invoice_Account__c, Contract_Customer__c, Contract_Customer__r.Name, Installation_Order_Status__c, Installation_Start_date__c, Installation_End_date__c, Vessel_IMO__c, Vessel_Status__c, Invoice_Account__r.Name, Vessel_Name__c, Vessel_Name__r.Name, Contract__c, Contract__r.Name FROM Installation__c WHERE Contract__c = :contrId AND Installation_Order_Status__c NOT IN :excludedStatuses])
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
            Set<String> excludedStatuses = new Set<String>{STATUS_TERMINATED, STATUS_FUTURE_TERMINATED, STATUS_TERMINATION_PENDING};
            return [SELECT Id, Name, Invoice_Account__c, Invoice_Account__r.Name, Vessel_Name__c, Vessel_Name__r.Name, Contract__c, Contract__r.Name FROM Installation__c WHERE Contract__c = :contrId AND Installation_Order_Status__c NOT IN :excludedStatuses];
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
