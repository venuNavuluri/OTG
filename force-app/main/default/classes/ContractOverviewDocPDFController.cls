public class ContractOverviewDocPDFController
{
    public Contract contr { get; set; }
    //public SBQQ__Quote__c qt { get; set; }
    public List<Package__c> packList { get; set; }
    //public List<SBQQ__QuoteLine__c> qtLineList;
    public List<PackageWrapper> packWrapList { get; set; }
    public List<Installation__c> instList { get; set; }
    public Date Today { get { return Date.today(); } }
    public Integer version { get; set; }
    public String formattedDate { get; set; }
    public String formattedRenewalDate { get; set; }
    public Decimal totalInstallationCost { get; set; } 
    public String currencyIsoCode { get; set; }
    public List<InvoiceWrapper> invWrapList {get; set;}
    public Boolean hasInv {get; set;}
    
    public ContractOverviewDocPDFController(ApexPages.StandardController st) {
        contr = (Contract) st.getRecord();
        contr = [SELECT Id, Name, ContractNumber, SBQQ__Quote__c, AccountId, Account.Name, Account.Account_ID__c, Account.Address1__c, Account.Address2__c,Payment_Terms__c,Legal_Entity__r.Name,
                 Account.Address3__c, Account.Town_City__c, Account.County_State__c, Account.Postcode_Zipcode__c,
                 Account.Country__r.Name, SBQQ__Quote__r.SBQQ__PaymentTerms__c, Business_Unit__c, Renewal_Month__c, SBQQ__RenewalTerm__c, SBQQ__RenewalOpportunity__r.SBQQ__RenewedContract__r.Next_Renewal_Date__c,
                 Billing_Frequency__c, CurrencyIsoCode, Next_Renewal_Date__c, No_of_Installations__c, SBQQ__Opportunity__r.Account_Owner__c FROM Contract WHERE Id = :contr.Id];
        
        Map<Id, Package__c> packMap = new Map<Id, Package__c>([SELECT Id, Name, Quote__c, Products__c, Package_Number__c, Annual_Cost__c, InstallationCost__c, Installation_Cost__c, Installation_Quantity__c FROM Package__c WHERE Contract__c = :contr.Id AND Installation_Quantity__c > 0]);
        System.debug('packMap --> ' + packMap);
        
        List<AggregateResult> agrList = [SELECT Installation__r.Package__c Pack, Product__r.Name Prod, COUNT(Id) cnt FROM Installation_Line__c WHERE Installation__r.Package__c IN :packMap.keySet() GROUP BY Installation__r.Package__c, Product__r.Name];
        Map<Id, List<String>> packProdMap = new Map<Id, List<String>>();
        for(AggregateResult agr : agrList)
        {
            if(packProdMap.get((Id)agr.get('Pack')) == NULL)
            {
                packProdMap.put((Id)agr.get('Pack'), new List<String>());
            }
            packProdMap.get((Id)agr.get('Pack')).add((String)agr.get('Prod')) ;
        }
        System.debug('packPrdMap --> ' + packProdMap);
        
        packWrapList = new List<PackageWrapper>();
        
        List<Id> packIdList = new List<Id>();
        Map<String, List<ProductWrapper>> prodWrapMap = new Map<String, List<ProductWrapper>>();
        Set<String> packageNameProdStrSet = new Set<String>();
        
        for (Package__c pk : packMap.values())
        {
            // Skip if package has no package number or no products
            if (String.isBlank(pk.Package_Number__c) || String.isBlank(pk.Products__c)) {
                continue;
            }
        
            String packageNumber = pk.Package_Number__c.trim();
        
            // Initialise list for this package number if not present
            if (!prodWrapMap.containsKey(packageNumber)) {
                prodWrapMap.put(packageNumber, new List<ProductWrapper>());
            }
        
            // Split products only after we know Products__c is not blank
            for (String prod : pk.Products__c.split(';')) {
                if (String.isBlank(prod)) {
                    continue;
                }
        
                ProductWrapper pw = new ProductWrapper();
                pw.productName = prod;
                pw.previousCost = pk.InstallationCost__c;
                pw.instQuantity = pk.Installation_Quantity__c;
        
                prodWrapMap.get(packageNumber).add(pw);
                packageNameProdStrSet.add(packageNumber + pw.productName);
                packIdList.add(pk.Id);
            }
        }
        System.debug('prodWrapMap --> ' + prodWrapMap);

        
        for (String packageNumber : prodWrapMap.keySet()) {
            System.debug('pack num --> ' + packageNumber);
            System.debug('packageNumber size --> ' + prodWrapMap.get(packageNumber).size());
            PackageWrapper pw = new PackageWrapper();
            pw.packageName = packageNumber;
            pw.productWrapList = prodWrapMap.get(packageNumber);
            //pw.annualCost = prodWrapMap.get(packageNumber).size() > 0 ? prodWrapMap.get(packageNumber)[0].annualCost : 0;
            //pw.installationCost = prodWrapMap.get(packageNumber).size() > 0 ? prodWrapMap.get(packageNumber)[0].installationCost : 0;
            pw.previousCost = prodWrapMap.get(packageNumber).size() > 0 ? prodWrapMap.get(packageNumber)[0].previousCost : 0;
            pw.installationQuantity = prodWrapMap.get(packageNumber).size() > 0 ? prodWrapMap.get(packageNumber)[0].instQuantity : 0;
            System.debug('pw --> ' + pw);
            packWrapList.add(pw);
        }
        
        instList = [
            SELECT Id, Installation_Name__c, Vessel_Name__r.Vessel_IMO__c, Package__r.Package_Number__c, Invoice_Account__r.Account_ID__c,
            Invoice_Account__c, Invoice_Account__r.Name, Invoice_Account__r.Email__c,Invoice_Account__r.Invoice_Emails__c, Installation_Price__c,
            Invoice_Account__r.Address1__c, Invoice_Account__r.Address2__c, Invoice_Account__r.Address3__c,
            Invoice_Account__r.Town_City__c, Invoice_Account__r.County_State__c, Invoice_Account__r.Postcode_Zipcode__c,
            Invoice_Account__r.Country__r.Name, Package__r.Installation_Cost__c, Package__r.InstallationCost__c, CurrencyIsoCode
            FROM Installation__c
            WHERE Package__c IN :packMap.keySet() AND Installation_Order_Status__c != 'Terminated'
        ];
        
        totalInstallationCost = 0; // Initialize total cost
        currencyIsoCode = (instList != null && !instList.isEmpty()) ? instList[0].CurrencyIsoCode : '';
        Map<String, InvoiceWrapper> invWrapMap = new Map<String, InvoiceWrapper>();
        invWrapList = new List<InvoiceWrapper>();
        hasInv = FALSE;
        
        for(Installation__c inst : instList)
        {
            if(inst.Invoice_Account__r.Invoice_Emails__c != NULL && inst.Invoice_Account__r.Invoice_Emails__c != '')
            {
                inst.Invoice_Account__r.Invoice_Emails__c = inst.Invoice_Account__r.Invoice_Emails__c.replaceAll(';', '\n');
            }
            if (inst.Package__r.InstallationCost__c != null) {
                totalInstallationCost += inst.Package__r.InstallationCost__c;
            }
            
            if(inst.Invoice_Account__c != NULL && invWrapMap.get(inst.Invoice_Account__r.Account_ID__c) == NULL)
            {
                InvoiceWrapper invWrap = new InvoiceWrapper();
                invWrap.invAccNumber = inst.Invoice_Account__r.Account_ID__c;
                invWrap.invNameAddr = inst.Invoice_Account__r.Name + ', ' + 
                    (inst.Invoice_Account__r.Address1__c != NULL ? inst.Invoice_Account__r.Address1__c + ', ' : '') + 
                    (inst.Invoice_Account__r.Address2__c != NULL ? inst.Invoice_Account__r.Address2__c + ', ' : '') +
                    (inst.Invoice_Account__r.Address3__c != NULL ? inst.Invoice_Account__r.Address3__c + ', ' : '') + 
                    (inst.Invoice_Account__r.Town_City__c != NULL ? inst.Invoice_Account__r.Town_City__c + ', ' : '') +
                    (inst.Invoice_Account__r.County_State__c != NULL ? inst.Invoice_Account__r.County_State__c + ', ' : '' ) +
                    (inst.Invoice_Account__r.Postcode_Zipcode__c != NULL ? inst.Invoice_Account__r.Postcode_Zipcode__c + ', ' : '') +
                    (inst.Invoice_Account__r.Country__c != NULL ? inst.Invoice_Account__r.Country__r.Name : '');
                invWrap.invEmail = inst.Invoice_Account__r.Invoice_Emails__c != NULL ? inst.Invoice_Account__r.Invoice_Emails__c.replaceAll(';', '\n') : '';
                invWrapMap.put(inst.Invoice_Account__r.Account_ID__c, invWrap);
                hasInv = TRUE;
            }
        }
        
        invWrapList.addAll(invWrapMap.values());

        Date today = Date.today();        
        String title = contr.Account.Name + '-Contract Overview ';
        List<ContentVersion> cvList = [SELECT ContentDocumentId FROM ContentVersion WHERE Title LIKE :title + '%'];
        version = (cvList != null && !cvList.isEmpty()) ? cvList.size() + 1 : 1;
        System.debug('title 2 --> ' + title);
        title += today.day() + '_' + today.month() + '_' + today.year();
        System.debug('title 1 --> ' + title);
        
        // Format the date dynamically
        formattedDate = DateTime.newInstance(today.year(), today.month(), today.day()).format('MM/yyyy');
        Date renewalDate = contr.SBQQ__RenewalOpportunity__r.SBQQ__RenewedContract__r.Next_Renewal_Date__c;
        if (renewalDate != null) {
            formattedRenewalDate = formatDateWithOrdinal(renewalDate);
        } else {
            formattedRenewalDate = 'Unknown Date'; // Fallback if the date is null
        }
        
        System.debug('title --> ' + title);
        Apexpages.currentPage().getHeaders().put('content-disposition', 'inline; filename='+title+'.pdf');
    }
    
    public static String formatDateWithOrdinal(Date inputDate) {
        Integer day = inputDate.day();
        String dayWithSuffix;
        
        // Handle ordinal suffix
        if (day >= 11 && day <= 13) {
            dayWithSuffix = day + 'th';
        } else {
            Integer remainder = Math.mod(day, 10);
            switch on remainder {
                when 1 { dayWithSuffix = day + 'st'; }
                when 2 { dayWithSuffix = day + 'nd'; }
                when 3 { dayWithSuffix = day + 'rd'; }
                when else { dayWithSuffix = day + 'th'; }
            }
        }
        
        // Use DateTime to format month and year
        DateTime dt = DateTime.newInstance(inputDate.year(), inputDate.month(), inputDate.day());
        String monthName = dt.format('MMMM'); // Full month name
        String year = String.valueOf(inputDate.year());
        
        return dayWithSuffix + ' ' + monthName + ' ' + year;
    }
    
    public class PackageWrapper {
        public String packageName { get; set; }
        public List<ProductWrapper> productWrapList { get; set; }
        public Decimal annualCost { get; set; }
        public Decimal installationCost { get; set; }
        public Decimal previousCost { get; set; }
        public Decimal installationQuantity { get; set; }
    }
    
    public class InvoiceWrapper
    {
        public String invAccNumber {get; set;}
        public String invEmail {get; set;}
        public String invNameAddr {get; set;}
    }
    
    public class ProductWrapper {
        public String productName { get; set; }
        public Decimal annualCost { get; set; }
        public Decimal installationCost { get; set; }
        public Decimal previousCost { get; set; }
        public Boolean removeFromPackage { get; set; }
        public Decimal qlquantity { get; set; }
        public Decimal instQuantity { get; set; }
    }
}