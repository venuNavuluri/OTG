public class InstallationTriggerHandler
{
    public static Boolean byPassSOcreation = FALSE;
    public static void beforeInsert(List<Installation__c> instList)
    {
        try
        {
            // Retrieve the current user's alias
            String currentUserAlias = [SELECT Alias FROM User WHERE Id = :UserInfo.getUserId()].Alias;
            
            // Bypass the logic if the current user alias is 'duser'
            if (currentUserAlias == 'duser') {
                return; // Exit the method
            }
            List<String> contractList = new List<String>();
            Map<String, Installation__c> contVessStatusMap = new Map<String, Installation__c>();
            Map<String, Installation__c> contOrgStatusMap = new Map<String, Installation__c>();
            Map<String, Installation__c> conInstMap = new Map<String, Installation__c>();
            for(Installation__c inst : instList)
            {
                contractList.add(inst.Contract_Customer__c);
                System.debug('vess name --> ' + inst.Vessel_Name__c);
                if(inst.Vessel_Name__c != NULL)
                {
                    contVessStatusMap.put(inst.Contract_Customer__c + '-' + inst.Vessel_Name__c, inst);
                }
                else
                {
                    contOrgStatusMap.put(inst.Contract_Customer__c + '-' + inst.Organisation_Name__c, inst);
                }
                if(inst.Contract__c != NULL)
                {
                    conInstMap.put(inst.Contract__c, inst);
                }
            }
            List<Installation__c> instRecList = [SELECT Id, Name, Contract__c, Contract_Customer__c, Organisation_Name__c, Vessel_Name__c, Installation_Order_Status__c FROM Installation__c WHERE Contract_Customer__c IN :contractList AND Installation_Order_Status__c = 'Active'];
            for(Installation__c inst : instRecList)
            {
                if(contOrgStatusMap.keySet().contains (inst.Contract_Customer__c + '-' + inst.Organisation_Name__c))
                {
                    contOrgStatusMap.get(inst.Contract_Customer__c + '-' + inst.Organisation_Name__c).addError('Installation record already present, duplicate installation record not allowed.');
                }
                else if(contVessStatusMap.keySet().contains(inst.Contract_Customer__c + '-' + inst.Vessel_Name__c))
                {
                    contVessStatusMap.get(inst.Contract_Customer__c + '-' + inst.Vessel_Name__c).addError('Installation record already present, duplicate installation record not allowed.');
                }
            }
            
            if(!conInstMap.isEmpty())
            {
                List<Contract> conList = [SELECT Id, Name, StartDate, EndDate FROM Contract WHERE Id IN :conInstMap.keySet() AND StartDate != NULL AND EndDate != NULL];
                if(!conList.isEmpty())
                {
                    for(Contract con : conList)
                    {
                        conInstMap.get(con.Id).Installation_Start_date__c = con.StartDate;
                        conInstMap.get(con.Id).Installation_End_date__c = con.EndDate;
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
    
    public static void afterUpdate(List<Installation__c> instList, Map<Id, Installation__c> oldInstMap)
    {
        try
        {
            List<Id> instIdList = new List<Id>();
            List<Installation__c> activeInstList = new List<Installation__c>();
            String currentUserAlias = [SELECT Alias FROM User WHERE Id = :UserInfo.getUserId()].Alias;
            
            for(Installation__c inst : instList)
            {
                if(currentUserAlias != 'duser'){
                    if(inst.Installation_Order_Status__c == 'Terminated' && oldInstMap.get(inst.Id).Installation_Order_Status__c != 'Terminated')
                    {
                        instIdList.add(inst.Id);
                    }
                    else if(inst.Installation_Order_Status__c == 'Active' && oldInstMap.get(inst.Id).Installation_Order_Status__c != 'Active')
                    {
                        activeInstList.add(inst);
                    }   
                }
                
            }
            System.debug('instIdList --> ' + instIdList);
            if(!instIdList.isEmpty())
            {
                List<Sales_Order__c> soList = [SELECT Id, Name, Billing_Frequency__c, Contract__c, CurrencyIsoCode, Installation__c, Installation__r.Termination_End_Date__c, Invoice_Account__c, OwnerId, Total_Amount__c, Status__c, Start_Date__c, End_Date__c FROM Sales_Order__c WHERE Installation__c IN :instIdList AND End_Date__c > :Date.Today()];
                System.debug('soList --> ' + soList);
                List<Sales_Order_Item__c> newSOIList = new List<Sales_Order_Item__c>();
                List<Id> soIdList = new List<Id>();
                List<Sales_Order__c> soListToUpdate = new List<Sales_Order__c>();
                Map<Id, Sales_Order__c> oldSOIdNewSOMap = new Map<Id, Sales_Order__c>();
                for(Sales_Order__c so : soList)
                {
                    System.debug('So status --> ' + so.Status__c);
                    
                    if(so.Status__c == 'Billed')
                    {
                        soIdList.add(so.Id);
                        Sales_Order__c newSO = so.clone();
                        newSO.Status__c = 'Terminated';
                        newSO.Start_Date__c = so.Installation__r.Termination_End_Date__c;
                        oldSOIdNewSOMap.put(so.Id, newSO);
                    }
                    else
                    {
                        so.Status__c = 'Unbilled';
                        soListToUpdate.add(so);
                    }
                    //}
                }
                if(!soListToUpdate.isEmpty())
                {
                    update soListToUpdate;
                }
                if(!oldSOIdNewSOMap.isEmpty())
                {
                    insert oldSOIdNewSOMap.values();
                }
                List<Sales_Order_Item__c> soiList = [SELECT Id, Name, Amount__c, Sales_Order__c, Sales_Order__r.Start_Date__c, Sales_Order__r.End_Date__c, Subscription__c, CurrencyIsoCode, Installation_Line__c FROM Sales_Order_Item__c WHERE Sales_Order__c IN :soIdList];
                for(Sales_Order_Item__c soi : soiList)
                {
                    Sales_Order_Item__c newsoi = soi.clone();
                    Integer days = soi.Sales_Order__r.Start_Date__c.daysBetween(soi.Sales_Order__r.End_Date__c);
                    Decimal amtPerDay = soi.Amount__c/days;
                    Integer daysFromToday = soi.Sales_Order__r.Start_Date__c.daysBetween(soi.Sales_Order__r.End_Date__c);
                    newsoi.Amount__c = soi.Sales_Order__r.Start_Date__c > Date.today() ? newsoi.Amount__c * (-1) : daysFromToday * amtPerDay * (-1);
                    newsoi.Sales_Order__c = oldSOIdNewSOMap.get(newsoi.Sales_Order__c).Id;
                    newsoiList.add(newsoi);
                }
                if(!newsoiList.isEmpty())
                {
                    insert newsoiList;
                }
            }
            
            if(!activeInstList.isEmpty())
            {
                CreateSalesOrderService.createSORecords(activeInstList);
                //CreateSalesOrderService.createSOIRecords(activeInstList);
            }
        }
        catch(Exception ex)
        {
            Logger.error(ex.getMessage() + '\n\n' + ex.getLineNumber() + '\n\n' + ex.getStackTraceString());
            Logger.saveLog();
        }
    }
    
}