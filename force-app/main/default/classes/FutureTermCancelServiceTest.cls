@IsTest
private class FutureTermCancelServiceTest {
    @TestSetup
    static void setup() {
        TestDataFactory_OTG.enableOrgVRConfig();
        TestDataFactory_OTG.primeDefaultOwnerAllRegions(UserInfo.getUserId());
    }

    @IsTest
    static void cancelRequestedFutureTerminationClearsTrackingAndQuoteFlag() {
        TestDataFactory_OTG.OrderContext oc =
            TestDataFactory_OTG.buildOrderContext('Americas', 'Amendment', 'Draft', false, true);

        update new SBQQ__Quote__c(
            Id = oc.qctx.quote.Id,
            Auto_Termination__c = true,
            Installation__c = oc.installation.Id
        );
        update new Installation__c(
            Id = oc.installation.Id,
            Installation_Order_Status__c = 'Future Terminated',
            Termination_End_Date__c = Date.today().addDays(30),
            Termination_Reason__c = 'Scheduled removal',
            Auto_Termination__c = true,
            Termination_Quote__c = oc.qctx.quote.Id,
            Termination_Order__c = oc.orderRec.Id,
            Termination_Process_Status__c = 'Waiting For Order Activation',
            Termination_Process_Error__c = 'Pending order activation',
            Auto_Installation_Termination_Error__c = 'Pending order activation'
        );

        Test.startTest();
        FutureTermCancelService.CancelResult result =
            FutureTermCancelService.cancelFutureTermination(oc.installation.Id);
        Test.stopTest();

        System.assertEquals(true, result.success);

        Installation__c refreshed = [
            SELECT Installation_Order_Status__c,
                   Termination_End_Date__c,
                   Termination_Reason__c,
                   Auto_Termination__c,
                   Termination_Quote__c,
                   Termination_Order__c,
                   Termination_Process_Status__c,
                   Termination_Process_Error__c,
                   Auto_Installation_Termination_Error__c
            FROM Installation__c
            WHERE Id = :oc.installation.Id
        ];
        System.assertEquals('Active', refreshed.Installation_Order_Status__c);
        System.assertEquals(null, refreshed.Termination_End_Date__c);
        System.assertEquals(null, refreshed.Termination_Reason__c);
        System.assertEquals(false, refreshed.Auto_Termination__c);
        System.assertEquals(null, refreshed.Termination_Quote__c);
        System.assertEquals(null, refreshed.Termination_Order__c);
        System.assertEquals(null, refreshed.Termination_Process_Status__c);
        System.assertEquals(null, refreshed.Termination_Process_Error__c);
        System.assertEquals(null, refreshed.Auto_Installation_Termination_Error__c);

        SBQQ__Quote__c quote = [
            SELECT Auto_Termination__c, Installation__c
            FROM SBQQ__Quote__c
            WHERE Id = :oc.qctx.quote.Id
        ];
        System.assertEquals(false, quote.Auto_Termination__c);
        System.assertEquals(null, quote.Installation__c);
    }

    @IsTest
    static void cancelFailedFutureTerminationIsAllowed() {
        TestDataFactory_OTG.OrderContext oc =
            TestDataFactory_OTG.buildOrderContext('Americas', 'Amendment', 'Draft', false, false);

        update new Installation__c(
            Id = oc.installation.Id,
            Installation_Order_Status__c = 'Future Terminated',
            Termination_End_Date__c = Date.today().addDays(30),
            Auto_Termination__c = true,
            Termination_Process_Status__c = 'Failed',
            Termination_Process_Error__c = 'CPQ error',
            Auto_Installation_Termination_Error__c = 'CPQ error'
        );

        Test.startTest();
        FutureTermCancelService.cancelFutureTermination(oc.installation.Id);
        Test.stopTest();

        Installation__c refreshed = [
            SELECT Installation_Order_Status__c, Termination_Process_Status__c, Auto_Installation_Termination_Error__c
            FROM Installation__c
            WHERE Id = :oc.installation.Id
        ];
        System.assertEquals('Active', refreshed.Installation_Order_Status__c);
        System.assertEquals(null, refreshed.Termination_Process_Status__c);
        System.assertEquals(null, refreshed.Auto_Installation_Termination_Error__c);
    }

    @IsTest
    static void cancelCompletedFutureTerminationIsBlocked() {
        TestDataFactory_OTG.OrderContext oc =
            TestDataFactory_OTG.buildOrderContext('Americas', 'Amendment', 'Draft', false, false);

        update new Installation__c(
            Id = oc.installation.Id,
            Installation_Order_Status__c = 'Future Terminated',
            Termination_End_Date__c = Date.today().addDays(30),
            Auto_Termination__c = true,
            Termination_Process_Status__c = 'Completed'
        );

        try {
            FutureTermCancelService.cancelFutureTermination(oc.installation.Id);
            System.assert(false, 'Completed future terminations should be blocked.');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
    }

    @IsTest
    static void cancelActivatedTerminationOrderIsBlocked() {
        TestDataFactory_OTG.OrderContext oc =
            TestDataFactory_OTG.buildOrderContext('Americas', 'Amendment', 'Draft', false, true);

        update new SBQQ__Quote__c(
            Id = oc.qctx.quote.Id,
            Auto_Termination__c = false,
            Installation__c = null
        );
        update new Order(
            Id = oc.orderRec.Id,
            Status = 'Activated',
            Is_Activated__c = true
        );
        update new Installation__c(
            Id = oc.installation.Id,
            Installation_Order_Status__c = 'Future Terminated',
            Termination_End_Date__c = Date.today().addDays(30),
            Auto_Termination__c = true,
            Termination_Order__c = oc.orderRec.Id,
            Termination_Process_Status__c = 'Waiting For Order Activation'
        );

        try {
            FutureTermCancelService.cancelFutureTermination(oc.installation.Id);
            System.assert(false, 'Activated termination orders should be blocked.');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
    }

    @IsTest
    static void cancelNonFutureTerminatedInstallationIsBlocked() {
        TestDataFactory_OTG.OrderContext oc =
            TestDataFactory_OTG.buildOrderContext('Americas', 'Amendment', 'Draft', false, false);

        update new Installation__c(
            Id = oc.installation.Id,
            Installation_Order_Status__c = 'Active'
        );

        try {
            FutureTermCancelService.cancelFutureTermination(oc.installation.Id);
            System.assert(false, 'Active installations should be blocked.');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
    }
}
