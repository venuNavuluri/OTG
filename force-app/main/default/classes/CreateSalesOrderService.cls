public class CreateSalesOrderService {
	public static void createSORecords(List<Installation__c> installations) {
		try {
			List<Installation__c> newInstList = [
				SELECT
					Id,
					Name,
					Invoice_Account__c,
					Auto_Installation__c,
					Auto_Termination__c,
					CurrencyIsoCode,
                	Quote__r.SBQQ__Type__c,
					Contract__r.SBQQ__Quote__r.SBQQ__Type__c,
					Contract__r.Migrated_Contract__c,
					Contract__r.StartDate,
					Contract__r.EndDate,
					Installation_Start_date__c,
					Installation_End_date__c,
					Contract__c,
					Contract__r.Billing_Frequency__c,
					Contract__r.ContractTerm
				FROM Installation__c
				WHERE Id IN :installations AND Installation_Order_Status__c = 'Active'
			];
            System.debug('inst list--> ' + newInstList);
			List<Sales_Order__c> salesOrdersToCreate = new List<Sales_Order__c>();
			Set<Date> startDateSet = new Set<Date>();
			Set<Date> endDateSet = new Set<Date>();

			Date earliestStartDate = Date.today();
			Date latestEndDate = Date.today();
            
            System.debug('newInstList --> ' + newInstList);

			for (Installation__c installation : newInstList) {
				Integer billingCycleMonths = getBillingCycleMonths(installation.Contract__r.Billing_Frequency__c);
				Integer contractTerm = installation.Auto_Installation__c
					? installation.Installation_Start_date__c.monthsBetween(installation.Installation_End_date__c)
					: installation.Contract__r.ContractTerm;
                
				for (Integer i = 0; i < (Math.ceil((Decimal) contractTerm/billingCycleMonths)); i++) {
					Date salesOrderStartDate = installation.Installation_Start_date__c.addMonths(i * billingCycleMonths);
					if (installation.Contract__r.Migrated_Contract__c && (installation.Quote__c == NULL || installation.Quote__r.SBQQ__Type__c != 'Amendment')) {
						salesOrderStartDate = installation.Contract__r.StartDate.addMonths(i * billingCycleMonths);
					}
                    if (installation.Quote__r.SBQQ__Type__c == 'Renewal') {
						salesOrderStartDate = installation.Contract__r.StartDate.addMonths(i * billingCycleMonths);
					}
					
					Date salesOrderEndDate = salesOrderStartDate.addMonths(billingCycleMonths).addDays(-1);
					Date instEndDate = installation.Installation_End_date__c == null
						? installation.Contract__r.EndDate
						: installation.Installation_End_date__c;

					Sales_Order__c salesOrder = new Sales_Order__c(
						Contract__c = installation.Contract__c,
						Invoice_Account__c = installation.Invoice_Account__c,
						Installation__c = installation.Id,
						Start_Date__c = salesOrderStartDate,
						End_Date__c = salesOrderEndDate > instEndDate ? instEndDate : salesOrderEndDate,
						Status__c = 'Unbilled',
						CurrencyIsoCode = installation.CurrencyIsoCode
					);
                    System.debug('salesOrder --> ' + salesOrder);

					salesOrdersToCreate.add(salesOrder);
					startDateSet.add(salesOrderStartDate);
					endDateSet.add(salesOrderEndDate);
					earliestStartDate = earliestStartDate > salesOrderStartDate ? salesOrderStartDate : earliestStartDate;
					latestEndDate = latestEndDate < salesOrderEndDate ? salesOrderEndDate : latestEndDate;
				}
			}
            System.debug('salesOrdersToCreate --> ' + salesOrdersToCreate);

			if (!salesOrdersToCreate.isEmpty()) {
				insert salesOrdersToCreate;
			}
			createSOIRecords(installations, salesOrdersToCreate, earliestStartDate, latestEndDate);
		} catch (Exception ex) {
            System.debug(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
			Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
			Logger.saveLog();
		}
	}

	public static void createSOIRecords(
		List<Installation__c> installations,
		List<Sales_Order__c> soList,
		Date earliestStartDate,
		Date latestEndDate
	) {
		try {
			List<Id> instIdList = new List<Id>();
			for (Installation__c inst : installations) {
				instIdList.add(inst.Id);
			}
			System.debug('instIdList --> ' + instIdList);
			System.debug('earliestStartDate --> ' + earliestStartDate);
			System.debug('latestEndDate --> ' + latestEndDate);
			List<Installation_Line__c> installationLines = [
				SELECT
					Id,
					Name,
					Installation__c,
					Product__c,
					Quote_Line__c,
					CurrencyIsoCode,
					Net_Total__c,
					Subscription__c,
					Start_Date__c,
					End_Date__c
				FROM Installation_Line__c
				WHERE Installation__c IN :instIdList AND Start_Date__c >= :earliestStartDate AND End_Date__c <= :latestEndDate
			];

			System.debug('installationLines --> ' + installationLines);

			Map<Id, List<Installation_Line__c>> installationLineMap = new Map<Id, List<Installation_Line__c>>();
			for (Installation_Line__c line : installationLines) {
				if (!installationLineMap.containsKey(line.Installation__c)) {
					installationLineMap.put(line.Installation__c, new List<Installation_Line__c>());
				}
				installationLineMap.get(line.Installation__c).add(line);
			}
			System.debug('installationLineMap --> ' + installationLineMap);
			List<Sales_Order_Item__c> salesOrderItemsToCreate = new List<Sales_Order_Item__c>();
			for (Sales_Order__c salesOrder : soList) {
				List<Installation_Line__c> relatedLines = installationLineMap.get(salesOrder.Installation__c);
				if (relatedLines != null && !relatedLines.isEmpty()) {
					for (Installation_Line__c line : relatedLines) {
						System.debug('line ' + line.Start_Date__c + '---' + line.End_Date__c);
						System.debug('so ' + salesOrder.Start_Date__c + '---' + salesOrder.End_Date__c);
                        System.debug('check --> ' + (line.Start_Date__c <= salesOrder.Start_Date__c && line.End_Date__c >= salesOrder.End_Date__c));
						if (line.Start_Date__c <= salesOrder.Start_Date__c && line.End_Date__c >= salesOrder.End_Date__c) {
							Double proratedAmount = calculateProratedAmount(line, salesOrder);
							System.debug('in if');
							Sales_Order_Item__c salesOrderItem = new Sales_Order_Item__c(
								Name = line.Name,
								Sales_Order__c = salesOrder.Id,
								Installation_Line__c = line.Id,
								Subscription__c = line.Subscription__c,
								CurrencyIsoCode = line.CurrencyIsoCode,
								Amount__c = proratedAmount
							);
							salesOrderItemsToCreate.add(salesOrderItem);
						}
					}
				}
			}

			if (!salesOrderItemsToCreate.isEmpty()) {
				InstallationTriggerHandler.byPassSOcreation = true;
				insert salesOrderItemsToCreate;
			}
		} catch (Exception ex) {
			Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
			Logger.saveLog();
		}
	}

	@TestVisible
	private static Integer getBillingCycleMonths(String billingFrequency) {
		if (billingFrequency == 'Annual') {
			return 12;
		} else if (billingFrequency == 'Semiannual') {
			return 6;
		} else if (billingFrequency == 'Quarterly') {
			return 3;
		} else if (billingFrequency == 'Monthly') {
			return 1;
		} else {
			return 12; // Default to monthly if frequency is unknown
		}
	}

	public static Double calculateProratedAmount(Installation_Line__c line, Sales_Order__c salesOrder) {
    Double proratedAmount = 0;
    try {
        if (
            line.Start_Date__c.day() == line.End_Date__c.addDays(1).day() &&
            salesOrder.Start_Date__c.day() == salesOrder.End_Date__c.addDays(1).day()
        ) {
            // Full-month aligned → use month-based proration
            Double totalMonths = (Double) line.Start_Date__c.monthsBetween(line.End_Date__c.addDays(1));
            Double soMonths = (Double) salesOrder.Start_Date__c.monthsBetween(salesOrder.End_Date__c.addDays(1));
            proratedAmount = (soMonths / totalMonths) * line.Net_Total__c;
        } else {
            // Not aligned → use day-based proration
            Double totalDays = (Double) line.Start_Date__c.daysBetween(line.End_Date__c) + 1;
            Double soDays = (Double) salesOrder.Start_Date__c.daysBetween(salesOrder.End_Date__c) + 1;
            proratedAmount = (soDays / totalDays) * line.Net_Total__c;
        }
    } catch (Exception ex) {
        Logger.error('Error in calculateProratedAmount: ' + ex.getMessage() + '\n' + ex.getStackTraceString());
        Logger.saveLog();
    }
    return proratedAmount;
}
}