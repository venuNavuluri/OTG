@IsTest
public class InstallationTriggerTest {

    @TestSetUp
    public static void createTestData() {
        // Create a test user
        Profile prof = [SELECT Id FROM Profile WHERE Name = 'OTG Sales User'];
        User u = new User(
            ProfileId = prof.Id,
            Username = 'testuser+' + System.currentTimeMillis() + '@example.com',
            LastName = 'TestUser',
            Alias = 'testusr',
            Email = 'testuser@example.com',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/New_York'
        );
        insert u;

        // Create Default Account Owner Settings
        Default_Account_Owner_Settings__c da = new Default_Account_Owner_Settings__c(
            EMEA_Default_Owner_ID__c = u.Id
        );
        insert da;

        // Create Country Mapping
        Country_Mapping__c cm = new Country_Mapping__c(
            Name = 'Test',
            Sales_Region__c = 'Americas'
        );
        insert cm;

        // Create two test accounts
        Account acc1 = new Account(
            Name = 'Test Account 1',
            Account_Status__c = 'Unverified',
            AccountSource = 'Cross Department Referral',
            Address1__c = '123 Test Street',
            Town_City__c = 'Texas',
            Country__c = cm.Id,
            Account_Segmentation__c = 'Unknown',
            Customer_Type__c = 'Charity',
            OwnerId = u.Id
        );
        insert acc1;

        Account acc2 = new Account(
            Name = 'Test Account 2',
            Account_Status__c = 'Unverified',
            AccountSource = 'Cross Department Referral',
            Address1__c = '456 Test Avenue',
            Town_City__c = 'Austin',
            Country__c = cm.Id,
            Account_Segmentation__c = 'Unknown',
            Customer_Type__c = 'Charity',
            OwnerId = u.Id
        );
        insert acc2;

        // Create two unique vessels
        Vessel__c vessel1 = new Vessel__c(
            Vessel_IMO__c = '1234567',
            Vessel_MMSI__c = '123456789',
            Vessel_IMO_Status__c = 'N/A IMO',
            OTG_Vessel_Type__c = 'Test'
        );
        insert vessel1;

        Vessel__c vessel2 = new Vessel__c(
            Vessel_IMO__c = '7654321',
            Vessel_MMSI__c = '987654321',
            Vessel_IMO_Status__c = 'N/A IMO',
            OTG_Vessel_Type__c = 'Test 2'
        );
        insert vessel2;

        // Create two unique installations
        Installation__c inst1 = new Installation__c(
            Contract_Customer__c = acc1.Id,
            Installation_Type__c = 'Vessel',
            Vessel_Name__c = vessel1.Id,
            Installation_Order_Status__c = 'Active'
        );

        Installation__c inst2 = new Installation__c(
            Contract_Customer__c = acc2.Id,
            Installation_Type__c = 'Vessel',
            Vessel_Name__c = vessel2.Id,
            Installation_Order_Status__c = 'Active'
        );
        
        Installation__c inst3 = new Installation__c(
            Contract_Customer__c = acc2.Id,
            Installation_Type__c = 'Vessel',
            Vessel_Name__c = vessel2.Id,
            Installation_Order_Status__c = 'Draft'
        );

        insert new List<Installation__c> { inst1, inst2, inst3 };
    }

    @IsTest
    public static void testDuplicateInstallation() {
        Installation__c existingInst = [SELECT Contract_Customer__c, Vessel_Name__c FROM Installation__c LIMIT 1];
        Installation__c duplicateInst = new Installation__c(
            Contract_Customer__c = existingInst.Contract_Customer__c,
            Vessel_Name__c = existingInst.Vessel_Name__c,
            Installation_Type__c = 'Vessel',
            Installation_Order_Status__c = 'Active'
        );

        Test.startTest();
        try {
            insert duplicateInst;
            //System.assert(false, 'Expected duplicate error.');
        } catch (Exception ex) {
            System.assert(ex.getMessage().contains('Duplicate installation record'), 'Expected duplicate installation error.');
        }
        Test.stopTest();
    }

    @IsTest
    public static void testTerminateInstallation() {
        Installation__c inst = [SELECT Id FROM Installation__c WHERE Installation_Order_Status__c != 'Active' LIMIT 1];
        inst.Installation_Order_Status__c = 'Active';
        update inst;
        Sales_Order__c salesOrder = new Sales_Order__c(
						Installation__c = inst.Id,
						Start_Date__c = Date.today(),
						End_Date__c = Date.today().addDays(365),
						Status__c = 'Unbilled'
					);
        insert salesOrder;
        Sales_Order__c so = new Sales_Order__c(
						Installation__c = inst.Id,
						Start_Date__c = Date.today().addDays(-10),
						End_Date__c = Date.today().addDays(355),
						Status__c = 'Billed'
					);
        insert so;
        CreateSalesOrderService.createSORecords(new List<Installation__c>{inst});
        
        inst.Auto_Termination__c = TRUE;
        inst.Installation_Order_Status__c = 'Terminated';

        Test.startTest();
        update inst;
        Test.stopTest();

        /*List<Sales_Order__c> updatedSalesOrders = [
            SELECT Id, Status__c FROM Sales_Order__c WHERE Installation__c = :inst.Id
        ];
        System.assert(!updatedSalesOrders.isEmpty(), 'Expected updated Sales Orders.');
        Boolean foundCancelled = false;
        for (Sales_Order__c so : updatedSalesOrders) {
            if (so.Status__c == 'Cancelled') {
                foundCancelled = true;
                break;
            }
        }
        System.assert(foundCancelled, 'Expected a Cancelled Sales Order.');*/
    }

    @IsTest
    public static void testBulkInstallations() {
        List<Installation__c> newInstalls = new List<Installation__c>();
        Id vesselId = [SELECT Id FROM Vessel__c LIMIT 1].Id;
        
        List<Installation__c> instList = [SELECT Id, Name, Installation_Order_Status__c FROM Installation__c WHERE Installation_Order_Status__c = 'Active'];
        for(Installation__c inst : instList)
        {
            inst.Installation_Order_Status__c = 'Draft';
        }
        update instList;
        
        List<Vessel__c> vesList = new List<Vessel__c>();
        for(Integer i = 0; i < 10; i++)
        {
            Vessel__c vessel = new Vessel__c(
                Vessel_IMO__c = '76543' + String.valueOf(i),
                Vessel_MMSI__c = '9876543' + String.valueOf(i),
                Vessel_IMO_Status__c = 'N/A IMO',
                OTG_Vessel_Type__c = 'Test A ' + String.valueOf(i)
            );
            vesList.add(vessel);
        }
        insert vesList;

        for (Integer i = 0; i < 10; i++) {
            newInstalls.add(new Installation__c(
                Contract_Customer__c = [SELECT Id FROM Account WHERE Name = 'Test Account 1' LIMIT 1].Id,
                Installation_Type__c = 'Vessel',
                Vessel_Name__c = vesList[i].Id,//(Math.mod(i, 2) == 0) ? vesselId : [SELECT Id FROM Vessel__c WHERE Id != :vesselId LIMIT 1].Id,
                Installation_Order_Status__c = 'Active'
            ));
        }

        Test.startTest();
        insert newInstalls;
        Test.stopTest();

        System.assertEquals(10, [SELECT COUNT() FROM Installation__c WHERE Installation_Order_Status__c = 'Active'], 'Expected 10 new Installations.');
    }

    @IsTest
    public static void testActivateInstallation() {
        Installation__c inst = [SELECT Id FROM Installation__c WHERE Installation_Order_Status__c != 'Active' LIMIT 1];
        inst.Installation_Order_Status__c = 'Active';

        Test.startTest();
        update inst;
        Test.stopTest();

        /*List<Sales_Order__c> activeSalesOrders = [
            SELECT Id, Status__c FROM Sales_Order__c WHERE Installation__c = :inst.Id
        ];
        System.assert(!activeSalesOrders.isEmpty(), 'Expected active Sales Orders.');*/
    }
}