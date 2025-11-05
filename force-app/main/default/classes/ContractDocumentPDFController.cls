public class ContractDocumentPDFController {
    public SBQQ__Quote__c qt { get; set; }
    public List<Package__c> packList { get; set; }
    public List<SBQQ__QuoteLine__c> qtLineList;
    public List<PackageWrapper> packWrapList { get; set; }
    public List<Installation__c> instList { get; set; }
    //public Contract contr { get; set; }
    public Date Today { get { return Date.today(); } }
    public Integer version { get; set; }
    public String formattedDate { get; set; }
    public String formattedRenewalDate { get; set; }
    public Decimal totalInstallationCost { get; set; } 
    public String currencyIsoCode { get; set; }
    public List<InvoiceWrapper> invWrapList {get; set;}
    public Boolean hasInv {get; set;}
    
    public ContractDocumentPDFController(ApexPages.StandardController st) {
        qt = (SBQQ__Quote__c) st.getRecord();
        
        qt = [
            SELECT Id, Name, Legal_Entity__r.Country__r.Name, Total_Installations__c, SBQQ__Opportunity2__c, SBQQ__Opportunity2__r.Business_Unit__c,
            SBQQ__Opportunity2__r.SBQQ__RenewedContract__r.Renewal_Month__c, SBQQ__Opportunity2__r.SBQQ__RenewedContract__r.Next_Renewal_Date__c,
            SBQQ__PaymentTerms__c, SBQQ__Opportunity2__r.Account_Owner__c, SBQQ__Opportunity2__r.SBQQ__RenewedContract__r.No_of_Installations__c,
            SBQQ__Opportunity2__r.SBQQ__RenewedContract__r.SBQQ__RenewalUpliftRate__c, SBQQ__MasterContract__r.Next_Renewal_Date__c,
            SBQQ__MasterContract__r.Renewal_Month__c, SBQQ__Account__c, SBQQ__Account__r.Phone, SBQQ__Account__r.Address1__c, SBQQ__Account__r.Address2__c,
            SBQQ__Account__r.Address3__c, SBQQ__Account__r.Name, SBQQ__Account__r.Town_City__c, SBQQ__Account__r.County_State__c, SBQQ__Account__r.Postcode_Zipcode__c,
            SBQQ__Account__r.Country__r.Name, SBQQ__Account__r.Account_ID__c, Legal_Entity__c, Legal_Entity__r.Name, SBQQ__SubscriptionTerm__c,
            SBQQ__RenewalTerm__c, SBQQ__BillingFrequency__c, CurrencyIsoCode
            FROM SBQQ__Quote__c
            WHERE Id = :qt.Id
        ];
        
        qtLineList = [
            SELECT Id, Name, SBQQ__Product__c, SBQQ__Quantity__c, SBQQ__Product__r.Name, SBQQ__Group__c, SBQQ__Group__r.Package__c,
            SBQQ__Group__r.Package__r.Package_Name__c, SBQQ__Group__r.Package__r.Package_Number__c, SBQQ__Group__r.Package__r.Installation_Quantity__c,
            SBQQ__Group__r.Package__r.InstallationCost__c,SBQQ__Group__r.Installation_Price__c,SBQQ__Group__r.Installation_Quantity__c,
            SBQQ__Group__r.Package__r.Installation_Cost__c, Remove_Product_from_Package__c,SBQQ__Group__r.Current_Price__c
            FROM SBQQ__QuoteLine__c
            WHERE SBQQ__Quote__c = :qt.Id AND SBQQ__Group__r.Package__r.Installation_Quantity__c > 0
        ];
        
        //contr = [SELECT Id, Name, ContractNumber FROM Contract WHERE SBQQ__Order__r.SBQQ__Quote__c = :qt.Id];
        packWrapList = new List<PackageWrapper>();
        
        List<Id> packIdList = new List<Id>();
        Map<String, List<ProductWrapper>> prodWrapMap = new Map<String, List<ProductWrapper>>();
        Map<String, ProductWrapper> prdNameMap= new Map<String, ProductWrapper>();
        
        for (SBQQ__QuoteLine__c ql : qtLineList) {
            if (ql.SBQQ__Group__r.Package__r != null) {
                String packageNumber = ql.SBQQ__Group__r.Package__r.Package_Number__c;
                if (!prodWrapMap.containsKey(packageNumber)) {
                    prodWrapMap.put(packageNumber, new List<ProductWrapper>());
                }
                
                if(prdNameMap.get(packageNumber + '-' + ql.SBQQ__Product__r.Name) == NULL)
                {
                    ProductWrapper pw = new ProductWrapper();
                    pw.productName = ql.SBQQ__Product__r.Name;
                    pw.previousCost = ql.SBQQ__Group__r.Current_Price__c;
                    pw.installationCost = ql.SBQQ__Group__r.Installation_Price__c;
                    pw.removeFromPackage = ql.Remove_Product_from_Package__c;
                    pw.qlquantity = ql.SBQQ__Quantity__c;
                    pw.instQuantity = ql.SBQQ__Group__r.Installation_Quantity__c;
                    prodWrapMap.get(packageNumber).add(pw);
                    prdNameMap.put(packageNumber + '-' + ql.SBQQ__Product__r.Name, pw);
                }
                /*else
                {
                    ProductWrapper pw = prdNameMap.get(packageNumber + '-' + ql.SBQQ__Product__r.Name);
                }*/
                packIdList.add(ql.SBQQ__Group__r.Package__c);
            }
        }
        
        for (String packageNumber : prodWrapMap.keySet()) {
            PackageWrapper pw = new PackageWrapper();
            pw.packageName = packageNumber;
            pw.productWrapList = prodWrapMap.get(packageNumber);
            pw.annualCost = prodWrapMap.get(packageNumber).size() > 0 ? prodWrapMap.get(packageNumber)[0].annualCost : 0;
            pw.installationCost = prodWrapMap.get(packageNumber).size() > 0 ? prodWrapMap.get(packageNumber)[0].installationCost : 0;
            pw.previousCost = prodWrapMap.get(packageNumber).size() > 0 ? prodWrapMap.get(packageNumber)[0].previousCost : 0;
            pw.installationQuantity = prodWrapMap.get(packageNumber).size() > 0 ? prodWrapMap.get(packageNumber)[0].instQuantity : 0;
            packWrapList.add(pw);
        }
        
        instList = [
            SELECT Id, Installation_Name__c, Vessel_Name__r.Vessel_IMO__c, Package__r.Package_Number__c, Invoice_Account__r.Account_ID__c,
            Invoice_Account__c, Invoice_Account__r.Name, Invoice_Account__r.Email__c,Invoice_Account__r.Invoice_Emails__c,
            Invoice_Account__r.Address1__c, Invoice_Account__r.Address2__c, Invoice_Account__r.Address3__c,
            Invoice_Account__r.Town_City__c, Invoice_Account__r.County_State__c, Invoice_Account__r.Postcode_Zipcode__c,
            Invoice_Account__r.Country__r.Name, Package__r.Installation_Cost__c, CurrencyIsoCode, Package__r.Temp_Quote_Line_Group__r.Installation_Price__c
            FROM Installation__c
            WHERE Package__c IN :packIdList AND Installation_Order_Status__c != 'Terminated' AND Installation_Order_Status__c != 'Future Terminated'
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
            if (inst.Package__r.Temp_Quote_Line_Group__r.Installation_Price__c != null) {
                totalInstallationCost += inst.Package__r.Temp_Quote_Line_Group__r.Installation_Price__c;
            }
            
            if(inst.Invoice_Account__c != NULL && invWrapMap.get(inst.Invoice_Account__r.Account_ID__c) == NULL)
            {
                InvoiceWrapper invWrap = new InvoiceWrapper();
                invWrap.invAccNumber = inst.Invoice_Account__r.Account_ID__c;
                /*invWrap.invNameAddr = inst.Invoice_Account__r.Name + ', ' + inst.Invoice_Account__r.Address1__c + ', ' + 
                    inst.Invoice_Account__r.Address2__c + ', ' + inst.Invoice_Account__r.Address3__c + ', ' + 
                    inst.Invoice_Account__r.Town_City__c + ', ' + inst.Invoice_Account__r.County_State__c + ', ' +
                    inst.Invoice_Account__r.Postcode_Zipcode__c + ', ' + inst.Invoice_Account__r.Country__r.Name;*/
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
        
        String title = 'RenewalQuote_' +  qt.Name + '-' + qt.SBQQ__Account__r.Name + '_' + qt.SBQQ__Opportunity2__r.Business_Unit__c;
        List<ContentVersion> cvList = [SELECT ContentDocumentId FROM ContentVersion WHERE Title = :title];
        version = (cvList != null && !cvList.isEmpty()) ? cvList.size() + 1 : 1;
        
        // Format the date dynamically
        // Date today = Date.today();
        formattedDate = DateTime.newInstance(today.year(), today.month(), today.day()).format('MM/yyyy');
        Date renewalDate = qt.SBQQ__Opportunity2__r.SBQQ__RenewedContract__r.Next_Renewal_Date__c;
        if (renewalDate != null) {
            formattedRenewalDate = formatDateWithOrdinal(renewalDate);
        } else {
            formattedRenewalDate = 'Unknown Date'; // Fallback if the date is null
        }
        
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