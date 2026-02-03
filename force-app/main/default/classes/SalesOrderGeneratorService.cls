public class SalesOrderGeneratorService {

    public static void generateSalesOrders(List<Installation__c> installations, Boolean isRenewal, Boolean isPackageChange) {
        Savepoint sp = Database.setSavePoint();
        try {
            List<Installation__c> validInstallations = fetchInstallationsWithDetails(installations);
            if (validInstallations.isEmpty()) return;

            Map<Id, List<Installation_Line__c>> lineMap = fetchInstallationLinesGrouped(validInstallations);
            List<Sales_Order__c> salesOrders = new List<Sales_Order__c>();

            for (Installation__c inst : validInstallations) {
                List<Installation_Line__c> instLines = lineMap.get(inst.Id);
                if (instLines == null || instLines.isEmpty()) continue;

                Date instStart = isRenewal ? inst.Contract__r.StartDate : inst.Installation_Start_Date__c;
                Date instEnd = inst.Installation_End_Date__c;
                Date contractStart = inst.Contract__r.StartDate;
                
                // Order activation date (ActivatedDate -> EffectiveDate -> today)
                Date orderActivationDate;
                if (inst.Order__c != null && inst.Order__r.EffectiveDate != null) {
                    orderActivationDate = inst.Order__r.EffectiveDate;
                } else {
                    orderActivationDate = Date.today();
                }

                Integer interval = getBillingCycleMonths(inst.Contract__r.Billing_Frequency__c);
                
                // If package change, anchor BOTH contractStart & installStart to the Order activation date
                Date anchorContractStart = contractStart;
                Date anchorInstallStart  = isPackageChange ? orderActivationDate : instStart;

                List<BillingPeriod> billingPeriods =
                    generateBillingPeriods(anchorContractStart, instEnd, interval, anchorInstallStart);

                for (Integer i = 0; i < billingPeriods.size(); i++) {
                    Date periodStart = billingPeriods[i].startDate;
                    Date periodEnd = billingPeriods[i].endDate;

                    if (periodEnd < anchorInstallStart) continue;
                    if (periodStart > instEnd) continue;

                    if (periodStart < anchorInstallStart && anchorInstallStart <= periodEnd) {
                        periodStart = anchorInstallStart;
                    }

                    if (periodEnd > instEnd) periodEnd = instEnd;

                    salesOrders.add(new Sales_Order__c(
                        Contract__c = inst.Contract__c,
                        Invoice_Account__c = inst.Invoice_Account__c,
                        Installation__c = inst.Id,
                        Start_Date__c = periodStart,
                        End_Date__c = periodEnd,
                        Status__c = 'Pending Approval',
                        CurrencyIsoCode = inst.Contract__r.CurrencyIsoCode
                    ));
                }
            }

            insert salesOrders;
            Logger.info('Inserted Sales Orders: ' + salesOrders.size());
            Logger.saveLog();

            createSalesOrderItems(salesOrders, lineMap);

        } catch (Exception ex) {
            Database.rollback(sp);
            Logger.error('Sales Order generation failed: ' + ex.getMessage() + '\n' + ex.getStackTraceString());
            Logger.saveLog();
            throw new AuraHandledException('Sales Order creation failed: ' + ex.getMessage());
        }
    }

    private static List<Installation__c> fetchInstallationsWithDetails(List<Installation__c> installations) {
        return [
            SELECT Id, Contract__c, Invoice_Account__c, CurrencyIsoCode,
                   Installation_Start_Date__c, Installation_End_Date__c,
                   Contract__r.Billing_Frequency__c, Contract__r.StartDate,Contract__r.CurrencyIsoCode,
                   Order__c,Order__r.ActivatedDate,Order__r.EffectiveDate
            FROM Installation__c
            WHERE Id IN :installations
        ];
    }

    private static Map<Id, List<Installation_Line__c>> fetchInstallationLinesGrouped(List<Installation__c> installations) {
        Map<Id, List<Installation_Line__c>> lineMap = new Map<Id, List<Installation_Line__c>>();
        Set<Id> instIds = new Set<Id>();
        for (Installation__c inst : installations) instIds.add(inst.Id);

        List<Installation_Line__c> lines = [
            SELECT Id, Name, Installation__c, Subscription__c, Quote_Line__c,
                   Product__c, CurrencyIsoCode, Net_Total__c, Start_Date__c, End_Date__c
            FROM Installation_Line__c
            WHERE Installation__c IN :instIds AND End_Date__c > :Date.today()
        ];

        for (Installation_Line__c line : lines) {
            if (!lineMap.containsKey(line.Installation__c)) {
                lineMap.put(line.Installation__c, new List<Installation_Line__c>());
            }
            lineMap.get(line.Installation__c).add(line);
        }

        return lineMap;
    }

    private static void createSalesOrderItems(List<Sales_Order__c> salesOrders, Map<Id, List<Installation_Line__c>> lineMap) {
        List<Sales_Order_Item__c> soiToInsert = new List<Sales_Order_Item__c>();

        for (Sales_Order__c so : salesOrders) {
            List<Installation_Line__c> lines = lineMap.get(so.Installation__c);
            if (lines == null) continue;

            for (Installation_Line__c line : lines) {
                if (line.Start_Date__c <= so.End_Date__c && line.End_Date__c >= so.Start_Date__c) {
                    Double amount = calculateProratedAmount(line, so);
                    soiToInsert.add(new Sales_Order_Item__c(
                        Name = line.Name,
                        Sales_Order__c = so.Id,
                        Installation_Line__c = line.Id,
                        Subscription__c = line.Subscription__c,
                        CurrencyIsoCode = line.CurrencyIsoCode,
                        Amount__c = amount
                    ));
                }
            }
        }

        if (!soiToInsert.isEmpty()) {
            InstallationTriggerHandler.byPassSOcreation = true;
            insert soiToInsert;
            Logger.info('Inserted Sales Order Items: ' + soiToInsert.size());
            Logger.saveLog();
        }
    }

    @TestVisible
    private static List<BillingPeriod> generateBillingPeriods(Date contractStart, Date contractEnd, Integer interval, Date installStart) {
    List<BillingPeriod> periods = new List<BillingPeriod>();

    // Step 1: Find the first aligned billing period based on contract start
    Date firstAlignedStart = contractStart;
    while (firstAlignedStart.addMonths(interval) <= installStart) {
        firstAlignedStart = firstAlignedStart.addMonths(interval);
    }

    // Step 2: Calculate first billing period end
    Date firstPeriodEnd = getAccuratePeriodEnd(firstAlignedStart, interval);
    if (firstPeriodEnd > contractEnd) {
        firstPeriodEnd = contractEnd;
    }

    // Step 3: First billing period (from installStart to aligned period end)
    periods.add(new BillingPeriod(installStart, firstPeriodEnd));

    // Step 4: Remaining billing periods
    Date periodStart = firstPeriodEnd.addDays(1);
    while (periodStart <= contractEnd) {
        Date periodEnd = getAccuratePeriodEnd(periodStart, interval);
        if (periodEnd > contractEnd) {
            periodEnd = contractEnd;
        }
        periods.add(new BillingPeriod(periodStart, periodEnd));
        periodStart = periodEnd.addDays(1);
    }

    return periods;
}
    
    @TestVisible
    private static Date getAccuratePeriodEnd(Date startDate, Integer interval) {
    // Try adding interval months
    Date tentativeEnd = startDate.addMonths(interval);

    // If adding months skips to a shorter month (e.g., Feb), backtrack to last day of previous month
    if (startDate.day() > 28 && tentativeEnd.day() < startDate.day()) {
        Integer year = tentativeEnd.year();
        Integer month = tentativeEnd.month();

        // Get last day of the month
        Date monthEnd = Date.newInstance(year, month + 1, 1).addDays(-1);
        return monthEnd;
    }

    return tentativeEnd.addDays(-1);
}
    
    public static Double calculateProratedAmount(Installation_Line__c line, Sales_Order__c so) {
        try {
            if (line.Start_Date__c.day() == line.End_Date__c.addDays(1).day() &&
                so.Start_Date__c.day() == so.End_Date__c.addDays(1).day()) {
                Double totalMonths = (Double) line.Start_Date__c.monthsBetween(line.End_Date__c.addDays(1));
                Double soMonths = (Double) so.Start_Date__c.monthsBetween(so.End_Date__c.addDays(1));
                return (soMonths / totalMonths) * line.Net_Total__c;
            } else {
                Double totalDays = (Double) line.Start_Date__c.daysBetween(line.End_Date__c) + 1;
                Double soDays = (Double) so.Start_Date__c.daysBetween(so.End_Date__c) + 1;
                return (soDays / totalDays) * line.Net_Total__c;
            }
        } catch (Exception ex) {
            Logger.error('Error in calculateProratedAmount: ' + ex.getMessage() + '\n' + ex.getStackTraceString());
            Logger.saveLog();
            return 0;
        }
    }

    @TestVisible
    private static Integer getBillingCycleMonths(String billingFrequency) {
        if (billingFrequency == 'Monthly') return 1;
        if (billingFrequency == 'Quarterly') return 3;
        if (billingFrequency == 'Semiannual') return 6;
        if (billingFrequency == 'Annual') return 12;
        return 12;
    }

    public class BillingPeriod {
        public Date startDate;
        public Date endDate;

        public BillingPeriod(Date startDate, Date endDate) {
            this.startDate = startDate;
            this.endDate = endDate;
        }
    }
}