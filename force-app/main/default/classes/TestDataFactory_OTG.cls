@IsTest
public class TestDataFactory_OTG {

    // ---------- Lightweight contexts ----------
    public class QuoteContext {
        public Country_Mapping__c country;
        public Legal_Entity__c    legalEntity;
        public Account            b2bAccount;
        public Account            invoiceAccount;
        public Contact            contact;
        public Opportunity        opportunity;
        public Product2           product;
        public PricebookEntry     pbe;
        public SBQQ__Quote__c     quote; // Draft
        public List<SBQQ__QuoteLineGroup__c> groups = new List<SBQQ__QuoteLineGroup__c>();
        public List<SBQQ__QuoteLine__c>      lines  = new List<SBQQ__QuoteLine__c>();
    }

    // Handy wrapper if you want a one-call setup for a contract + its packages
    public class ContractPackageContext {
        public Contract              contractRec;
        public List<Package__c>      packages = new List<Package__c>();
    }
    
    // Context to drive Order-based tests
    public class OrderContext {
        public QuoteContext          qctx;
        public SBQQ__QuoteLineGroup__c qlg;
        public Package__c            packageRec;
        public Installation__c       installation;
        public Order                 orderRec;
    }


    // ---------- Caches to avoid repeat SOQL ----------
    private static Id standardPricebookId;
    private static Id invoiceAccountRecordTypeId;
    private static Map<String, Id> countryMappingIdByRegion = new Map<String, Id>(); // region -> Country_Mapping__c Id
    private static Id cachedProduct2Id;
    private static Id cachedPricebookEntryId;

    // ---------- Org/Flow setup ----------
    public static void enableOrgVRConfig() {
        VRConfiguration__c orgConfig = VRConfiguration__c.getOrgDefaults();
        if (orgConfig == null) orgConfig = new VRConfiguration__c();
        orgConfig.Quote_Ordered_Validation__c = true;
        upsert orgConfig;
    }

    // Prime ALL regions so your owner-setting Flow never sees null.
    public static void primeDefaultOwnerAllRegions(Id userId) {
        Default_Account_Owner_Settings__c ownerSettings = Default_Account_Owner_Settings__c.getOrgDefaults();
        if (ownerSettings == null) ownerSettings = new Default_Account_Owner_Settings__c();
        ownerSettings.EMEA_Default_Owner_ID__c     = userId;
        ownerSettings.Americas_Default_Owner_ID__c = userId;
        ownerSettings.APAC_Default_Owner_ID__c     = userId;
        upsert ownerSettings;
    }

    // ---------- Cached getters ----------
    public static Id getStandardPricebookIdCached() {
        if (standardPricebookId == null) standardPricebookId = Test.getStandardPriceBookId();
        return standardPricebookId;
    }
    public static Id getInvoiceAccountRecordTypeIdCached() {
        if (invoiceAccountRecordTypeId == null) {
            invoiceAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName()
                .get('Invoice Account').getRecordTypeId();
        }
        return invoiceAccountRecordTypeId;
    }
    public static Id getOrCreateCountryMappingId(String region) {
        String normalizedRegion = String.isBlank(region) ? 'Americas' : region;
        if (countryMappingIdByRegion.containsKey(normalizedRegion)) {
            return countryMappingIdByRegion.get(normalizedRegion);
        }
        Country_Mapping__c countryMapping = new Country_Mapping__c(
            Name = 'Test ' + normalizedRegion,
            Sales_Region__c = normalizedRegion
        );
        insert countryMapping;
        countryMappingIdByRegion.put(normalizedRegion, countryMapping.Id);
        return countryMapping.Id;
    }

    // ---------- Small builders (Accounts, Contacts, etc.) ----------
    public static Account createB2BAccount(Id ownerId, Id countryMappingId, String nameSuffix) {
        Account account = new Account(
            Name                    = 'B2B ' + (String.isBlank(nameSuffix) ? String.valueOf(Crypto.getRandomInteger()) : nameSuffix),
            OwnerId                 = ownerId, // explicit owner so Flow won’t null it
            Country__c              = countryMappingId,
            Account_Status__c       = 'Unverified',
            Account_Segmentation__c = 'Unknown',
            Customer_Type__c        = 'Charity',
            AccountSource           = 'Cross Department Referral',
            Address1__c             = '123 Test St',
            Town_City__c            = 'Test City'
        );
        insert account;
        return account;
    }

    public static Account createInvoiceAccount(Id ownerId, Id countryMappingId, Id b2bAccountId) {
        Account invoiceAccount = new Account(
            RecordTypeId      = getInvoiceAccountRecordTypeIdCached(),
            OwnerId           = ownerId,
            Name              = 'Invoice for ' + b2bAccountId,
            Company__c        = 'TestCo',
            CurrencyIsoCode   = 'USD',
            Invoice_Emails__c = 'billing@example.com',
            Town_City__c      = 'Billing Town',
            B2B_Account__c    = b2bAccountId,
            Country__c        = countryMappingId
        );
        insert invoiceAccount;
        return invoiceAccount;
    }

    public static Contact createContact(Id accountId, String lastName, Boolean withEmail) {
        Contact contact = new Contact(
            AccountId   = accountId,
            LastName    = String.isBlank(lastName) ? 'Test Contact' : lastName,
            Salutation  = 'Mr.', // required in your org
            Job_Role__c = 'Crew / Seafarer'
        );
        if (withEmail) {
            contact.Email = 'contact+' + String.valueOf(Crypto.getRandomInteger()) + '@example.com';
        }
        insert contact;
        return contact;
    }

    public static Legal_Entity__c createLegalEntity(Id countryMappingId) {
        Legal_Entity__c legalEntity = new Legal_Entity__c(
            Name       = 'Test Legal Entity',
            Country__c = countryMappingId
        );
        insert legalEntity;
        return legalEntity;
    }

    public static Opportunity createOpportunity(Id accountId, String name, Id legalEntityId) {
        Opportunity opportunity = new Opportunity(
            Name             = (String.isBlank(name) ? 'Opp ' + accountId : name),
            AccountId        = accountId,
            StageName        = 'Prospecting & Qualifying',
            CloseDate        = Date.today().addDays(30),
            Business_Unit__c = 'Technical Ship Management',
            LeadSource       = 'Existing Customer Relationship',
            Sales_Type__c    = 'Subscription',
            Amount           = 1000,
            Legal_Entity__c  = legalEntityId
        );
        insert opportunity;
        return opportunity;
    }

    // ---------- Product + PBE (cached) ----------
    public static Product2 getOrCreateProductCached() {
        if (cachedProduct2Id != null) return new Product2(Id = cachedProduct2Id);
        Product2 product = new Product2(
            Name            = 'OTG Test Product',
            IsActive        = true,
            Revenue_Type__c = 'Software : OLP Agreement'
        );
        insert product;
        cachedProduct2Id = product.Id;
        return product;
    }

    public static PricebookEntry getOrCreateStdPbeCached() {
        if (cachedPricebookEntryId != null) return new PricebookEntry(Id = cachedPricebookEntryId);
        Product2 product = getOrCreateProductCached();
        PricebookEntry pricebookEntry = new PricebookEntry(
            Product2Id   = product.Id,
            Pricebook2Id = getStandardPricebookIdCached(),
            UnitPrice    = 100,
            IsActive     = true
        );
        insert pricebookEntry;
        cachedPricebookEntryId = pricebookEntry.Id;
        return pricebookEntry;
    }

    // ---------- Quote + QLG + QL ----------
    public static SBQQ__Quote__c createDraftQuote(Id accountId, Id opportunityId, String typeIfAny) {
        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Account__c          = accountId,
            SBQQ__Opportunity2__c     = opportunityId,
            SBQQ__StartDate__c        = Date.today(),
            SBQQ__SubscriptionTerm__c = 12,
            SBQQ__PricebookId__c      = getStandardPricebookIdCached(),
            SBQQ__Primary__c          = true
        );
        if (!String.isBlank(typeIfAny)) quote.SBQQ__Type__c = typeIfAny;
        insert quote;
        return quote;
    }

    public static SBQQ__QuoteLineGroup__c createQuoteLineGroup(
        Id quoteId,
        String name,
        Boolean createdFromPackage,
        Integer installationQty
    ) {
        SBQQ__QuoteLineGroup__c qlg = new SBQQ__QuoteLineGroup__c(
            SBQQ__Quote__c           = quoteId,
            Name                     = (String.isBlank(name) ? 'Group' : name),
            Created_From_Package__c  = (createdFromPackage == null ? true : createdFromPackage),
            Installation_Quantity__c = (installationQty == null ? 1 : installationQty)
        );
        insert qlg;
        return qlg;
    }

    public static SBQQ__QuoteLine__c createQuoteLine(
        Id quoteId,
        Id groupId,
        Id pricebookEntryId,
        Integer quantity,
        Integer priorQuantity,
        Decimal netPrice,
        Date startDate,
        Date endDate,
        Id renewedSubscriptionId
    ) {
        // Ensure CPQ triggers have Product
        PricebookEntry pricebookEntry = [
            SELECT Id, Product2Id, Pricebook2Id
            FROM PricebookEntry
            WHERE Id = :pricebookEntryId
            LIMIT 1
        ];
        // Guard: PBE belongs to the Quote’s pricebook
        SBQQ__Quote__c quote = [
            SELECT Id, SBQQ__PricebookId__c
            FROM SBQQ__Quote__c
            WHERE Id = :quoteId
            LIMIT 1
        ];
        System.assertEquals(
            quote.SBQQ__PricebookId__c,
            pricebookEntry.Pricebook2Id,
            'PricebookEntry must belong to the same Pricebook as the Quote'
        );

        SBQQ__QuoteLine__c quoteLine = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c            = quote.Id,
            SBQQ__Group__c            = groupId,
            SBQQ__PricebookEntryId__c = pricebookEntry.Id,
            SBQQ__Product__c          = pricebookEntry.Product2Id, // critical for CPQ triggers
            SBQQ__Quantity__c         = quantity,
            SBQQ__NetPrice__c         = netPrice,
            SBQQ__StartDate__c        = startDate,
            SBQQ__EndDate__c          = endDate
            
        );
        if (priorQuantity != null)              quoteLine.SBQQ__PriorQuantity__c = priorQuantity;
        if (renewedSubscriptionId != null)      quoteLine.SBQQ__RenewedSubscription__c = renewedSubscriptionId;

        insert quoteLine;
        return quoteLine;
    }

    // ---------- One-call builder: Draft Quote context (running user) ----------
    public static QuoteContext buildDraftQuoteContext(String region, Boolean withInvoiceAccount, Boolean withContact) {
        String normalizedRegion = String.isBlank(region) ? 'Americas' : region;
        Id runningUserId = UserInfo.getUserId();

        // Prime org config & default owners BEFORE inserting Accounts
        enableOrgVRConfig();
        primeDefaultOwnerAllRegions(runningUserId); // <- key to avoid your Flow error

        QuoteContext context = new QuoteContext();

        Id countryMappingId = getOrCreateCountryMappingId(normalizedRegion);
        context.country = new Country_Mapping__c(Id = countryMappingId);

        context.b2bAccount = createB2BAccount(runningUserId, countryMappingId, String.valueOf(Crypto.getRandomInteger()));
        if (withInvoiceAccount) {
            context.invoiceAccount = createInvoiceAccount(runningUserId, countryMappingId, context.b2bAccount.Id);
        }
        if (withContact) {
            context.contact = createContact(context.b2bAccount.Id, 'Test Contact', true);
        }

        context.legalEntity = createLegalEntity(countryMappingId);
        context.opportunity = createOpportunity(context.b2bAccount.Id, 'Opp for ' + context.b2bAccount.Id, context.legalEntity.Id);

        context.product = getOrCreateProductCached();
        context.pbe     = getOrCreateStdPbeCached();

        context.quote   = createDraftQuote(context.b2bAccount.Id, context.opportunity.Id, null);
        context.groups.add(createQuoteLineGroup(context.quote.Id, 'G1', true, 1));
        context.groups.add(createQuoteLineGroup(context.quote.Id, 'G2', true, 1));

        return context;
    }

    // =====================================================================
    //                NEW: Contracts & Packages reusable builders
    // =====================================================================

    /**
     * Create a basic Contract record.
     * - currencyIso defaults to 'USD'
     * - startDate defaults to today
     * - termMonths defaults to 12
     * - if endDate is null, it’s derived from startDate + termMonths - 1 day
     */
    public static Contract createContractBasic(
        Id accountId,
        String currencyIso,
        Date startDate,
        Integer termMonths,
        Date endDate
    ) {
        Date startD = (startDate == null ? Date.today() : startDate);
        Integer term = (termMonths == null ? 12 : termMonths);
        Date endD = (endDate == null ? startD.addMonths(term).addDays(-1) : endDate);

        Contract ctr = new Contract(
            AccountId      = accountId,
            Status         = 'Draft',
            StartDate      = startD,
            ContractTerm   = term,
            EndDate        = endD,
            CurrencyIsoCode = String.isBlank(currencyIso) ? 'USD' : currencyIso
        );
        insert ctr;
        return ctr;
    }

    /**
     * Create ONE Package for a given Contract.
     * All numeric fields have sensible defaults if nulls are passed.
     */
    public static Package__c createPackageForContract(
        Id contractId,
        String packageName,
        String currencyIso,
        Integer installationQty,
        Integer userQty,
        Integer rapidTitles,
        Integer specialProducts,
        Integer virtualClassrooms
    ) {
        Package__c pkg = new Package__c(
            Contract__c                     = contractId,
            Name                            = String.isBlank(packageName) ? 'Pkg ' + contractId : packageName,
            Package_Name__c                 = String.isBlank(packageName) ? 'Pkg ' + contractId : packageName,
            CurrencyIsoCode                 = String.isBlank(currencyIso) ? 'USD' : currencyIso,
            Installation_Quantity__c        = (installationQty == null ? 1 : installationQty),
            User_Quantity__c                = (userQty == null ? 1 : userQty),
            Number_of_Rapid_Titles__c       = (rapidTitles == null ? 0 : rapidTitles),
            Number_of_Special_Products__c   = (specialProducts == null ? 0 : specialProducts),
            Number_of_Virtual_Classrooms__c = (virtualClassrooms == null ? 0 : virtualClassrooms)
        );
        insert pkg;
        return pkg;
    }

    /**
     * Create N Packages for a given Contract with simple sequential names.
     * All created packages share the same currency and base installation quantity.
     */
    public static List<Package__c> createPackagesForContract(
        Id contractId,
        Integer count,
        String currencyIso,
        Integer defaultInstallationQty
    ) {
        Integer howMany = (count == null || count <= 0) ? 1 : count;
        String ccy = String.isBlank(currencyIso) ? 'USD' : currencyIso;
        Integer installQty = (defaultInstallationQty == null ? 1 : defaultInstallationQty);

        List<Package__c> toInsert = new List<Package__c>();
        for (Integer i = 1; i <= howMany; i++) {
            toInsert.add(new Package__c(
                Contract__c                     = contractId,
                Name                            = 'Pkg-' + i,
                Package_Name__c                 = 'Pkg-' + i,
                CurrencyIsoCode                 = ccy,
                Installation_Quantity__c        = installQty,
                User_Quantity__c                = 1,
                Number_of_Rapid_Titles__c       = 0,
                Number_of_Special_Products__c   = 0,
                Number_of_Virtual_Classrooms__c = 0
            ));
        }
        insert toInsert;
        return toInsert;
    }

    /**
     * One-call convenience: create a Contract and N Packages under it.
     */
    public static ContractPackageContext buildContractWithPackages(
        Id accountId,
        String currencyIso,
        Integer termMonths,
        Integer packageCount,
        Integer defaultInstallationQty
    ) {
        ContractPackageContext ctx = new ContractPackageContext();
        ctx.contractRec = createContractBasic(
            accountId,
            String.isBlank(currencyIso) ? 'USD' : currencyIso,
            Date.today(),
            (termMonths == null ? 12 : termMonths),
            null
        );
        ctx.packages = createPackagesForContract(
            ctx.contractRec.Id,
            (packageCount == null ? 2 : packageCount),
            String.isBlank(currencyIso) ? 'USD' : currencyIso,
            (defaultInstallationQty == null ? 1 : defaultInstallationQty)
        );
        return ctx;
    }

    /**
     * Helper for Renewal path: attach a Contract to Opportunity.SBQQ__RenewedContract__c
     */
    public static void attachRenewedContractToOpportunity(Id opportunityId, Id contractId) {
        update new Opportunity(Id = opportunityId, SBQQ__RenewedContract__c = contractId);
    }
    
    // ---------- Vessel Helpers ----------
    private static Id cachedVesselId;
    
    public static Vessel__c getOrCreateVesselCached() {
        if (cachedVesselId != null) {
            return new Vessel__c(Id = cachedVesselId);
        }
        Vessel__c vessel = new Vessel__c(Name = 'Test Vessel', Vessel_IMO_Status__c = 'Active IMO', Vessel_IMO__c = '123456', Vessel_MMSI__c = '987654321');
        insert vessel;
        cachedVesselId = vessel.Id;
        return vessel;
    }
    
    public static List<Vessel__c> createVessels(Integer count) {
        Integer total = (count == null || count <= 0) ? 1 : count;
        List<Vessel__c> vesselsToInsert = new List<Vessel__c>();
        for (Integer i = 0; i < total; i++) {
            vesselsToInsert.add(new Vessel__c(Name = 'Test Vessel ' + i, Vessel_IMO_Status__c = 'Active IMO', Vessel_IMO__c = '12345' + i, Vessel_MMSI__c = '9876543' + i));
        }
        insert vesselsToInsert;
        return vesselsToInsert;
    }
    
    // ---------- Installation Helpers ----------
    public static Installation__c createInstallation(Id packageId, Id vesselId, String status) {
        Installation__c installation = new Installation__c(
            Package__c                   = packageId,
            Vessel_Name__c                    = vesselId, 
            Installation_Order_Status__c = String.isBlank(status) ? 'Pending Implementation' : status
        );
        insert installation;
        return installation;
    }
    
    public static List<Installation__c> createInstallations(Id packageId, Id vesselId, Integer count, String status) {
        Integer total = (count == null || count <= 0) ? 1 : count;
        List<Installation__c> installationsToInsert = new List<Installation__c>();
        for (Integer i = 0; i < total; i++) {
            installationsToInsert.add(new Installation__c(
                Package__c                   = packageId,
                Vessel_Name__c                    = vesselId, 
                Installation_Order_Status__c = String.isBlank(status) ? 'Pending Implementation' : status
            ));
        }
        insert installationsToInsert;
        return installationsToInsert;
    }
    
    /** Create an Order (defaults: Status=Draft, EffectiveDate=today, Std Pricebook) */
    public static Order createOrder(Id opportunityId, Id quoteId, String typeVal, String statusVal) {
        Order ord = new Order(
            OpportunityId = opportunityId,
            SBQQ__Quote__c = quoteId,
            Type = String.isBlank(typeVal) ? 'New' : typeVal,
            Status = String.isBlank(statusVal) ? 'Draft' : statusVal,
            EffectiveDate = Date.today(),
            Pricebook2Id = getStandardPricebookIdCached()
        );
        insert ord;
        return ord;
    }
    
    /** Add an OrderItem */
    public static OrderItem addOrderItem(Id orderId, Id pricebookEntryId, Decimal unitPrice, Decimal qty) {
        OrderItem oi = new OrderItem(
            OrderId = orderId,
            PricebookEntryId = pricebookEntryId,
            UnitPrice = (unitPrice == null ? 100 : unitPrice),
            Quantity = (qty == null ? 1 : qty)
        );
        insert oi;
        return oi;
    }
    
    /** Create a Package and wire it to a specific QLG/Quote for updatePackages + renewal path */
    public static Package__c createPackageLinkedToQLG(Id contractId, Id quoteId, SBQQ__QuoteLineGroup__c qlg, Integer instQty) {
        Package__c p = new Package__c(
            Contract__c = contractId,
            Name = 'Pkg-' + qlg.Id,
            Package_Name__c = 'Pkg-' + qlg.Id,
            CurrencyIsoCode = 'USD',
            Installation_Quantity__c = (instQty == null ? 1 : instQty),
            // important for OrderTriggerHandler.updatePackages packMap query
            Temp_Quote_Line_Group__c = qlg.Id,
            // helpful for renewal path in updateOrderIdOnInstallation
            Temp_Quote__c = quoteId,
            // good to have references for other logic
            Quote__c = quoteId,
            Quote_Line_Group__c = qlg.Id
        );
        insert p;
        return p;
    }
    
    /** Build a ready-to-use Order test context:
     *  - Draft Quote context
     *  - One extra user-created QLG
     *  - Package linked to that QLG
     *  - Draft Installation under the Package
     *  - Draft Order (type provided)
     *  Optionally mark quote flags (Auto_Installation/Auto_Termination) used by your logic
     */
    public static OrderContext buildOrderContext(
        String region,
        String orderType,
        String orderStatus,
        Boolean setQuoteAutoInstall,
        Boolean setQuoteAutoTerminate
    ) {
        // seed quote data
        QuoteContext qctx = buildDraftQuoteContext(region, false, false);
    
        // 1 user-created QLG (Created_From_Package__c = false) so syncPackageRecords/updatePackages see it
        SBQQ__QuoteLineGroup__c userQlg = createQuoteLineGroup(qctx.quote.Id, 'User QLG', false, 1);
    
        // package + installation (Draft → becomes Pending Implementation in non-renewal path)
        Contract ctr = createContractBasic(qctx.b2bAccount.Id, 'USD', Date.today(), 12, null);
        Package__c pack = createPackageLinkedToQLG(ctr.Id, qctx.quote.Id, userQlg, 1);
    
        Vessel__c v = getOrCreateVesselCached();
        Installation__c inst = new Installation__c(
            Package__c = pack.Id,
            Quote__c = qctx.quote.Id,
            Vessel_Name__c = v.Id,
            Installation_Order_Status__c = 'Draft'
        );
        insert inst;
    
        if (setQuoteAutoInstall == true || setQuoteAutoTerminate == true) {
            update new SBQQ__Quote__c(
                Id = qctx.quote.Id,
                Auto_Installation__c = (setQuoteAutoInstall == true),
                Auto_Termination__c  = (setQuoteAutoTerminate == true)
            );
        }
    
        // order
        Order ord = createOrder(qctx.opportunity.Id, qctx.quote.Id, orderType, orderStatus);
    
        // add an item so Order/Item queries are realistic
        addOrderItem(ord.Id, qctx.pbe.Id, 100, 1);
    
        OrderContext oc = new OrderContext();
        oc.qctx = qctx; oc.qlg = userQlg; oc.packageRec = pack; oc.installation = inst; oc.orderRec = ord;
        return oc;
    }
    
    /** Build a Renewal order context to exercise the Renewal path in updateOrderIdOnInstallation */
    public static OrderContext buildRenewalOrderContext() {
        QuoteContext qctx = buildDraftQuoteContext('Americas', false, false);
    
        // Renewal path: Package wired via Temp_Quote__c to the Quote
        Contract ctr = createContractBasic(qctx.b2bAccount.Id, 'USD', Date.today(), 12, null);
        SBQQ__QuoteLineGroup__c userQlg = createQuoteLineGroup(qctx.quote.Id, 'User QLG Ren', false, 1);
        Package__c pack = createPackageLinkedToQLG(ctr.Id, qctx.quote.Id, userQlg, 1);
    
        Vessel__c v = getOrCreateVesselCached();
        Installation__c inst = new Installation__c(
            Package__c = pack.Id,
            Quote__c   = qctx.quote.Id,
            Vessel_Name__c = v.Id,
            Installation_Order_Status__c = 'Draft'
        );
        insert inst;
    
        // Create the renewal order
        Order ord = createOrder(qctx.opportunity.Id, qctx.quote.Id, 'Renewal', 'Draft');
    
        // IMPORTANT: add at least one OrderItem so activation is allowed
        addOrderItem(ord.Id, qctx.pbe.Id, 100, 1);
    
        OrderContext oc = new OrderContext();
        oc.qctx = qctx;
        oc.qlg  = userQlg;
        oc.packageRec = pack;
        oc.installation = inst;
        oc.orderRec = ord;
        return oc;
    }
}