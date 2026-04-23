@IsTest
private class AutomationBypassTests {

    // Utility to reset state and user-level custom setting
    private static void reset() {
        AutomationBypass.clearTxn();
        Automation_Bypass_Settings__c cs = Automation_Bypass_Settings__c.getInstance(UserInfo.getUserId());
        // Only delete if a row actually exists (Id populated). getInstance() can return an
        // unsaved placeholder with null Id, which cannot be deleted.
        if (cs != null && cs.Id != null) {
            delete cs;
        }
    }

    private static Automation_Bypass_Settings__c ensureUserSetting() {
        Automation_Bypass_Settings__c cs = Automation_Bypass_Settings__c.getInstance(UserInfo.getUserId());
        if (cs == null || cs.Id == null) {
            cs = new Automation_Bypass_Settings__c(SetupOwnerId = UserInfo.getUserId());
        }
        return cs;
    }

    @IsTest
    static void persistent_bypass_via_flags_and_keys() {
        reset();
        // Org/user setting with trigger flag
        Automation_Bypass_Settings__c cs = ensureUserSetting();
        cs.Bypass_Triggers__c = true;
        cs.Bypass_All__c = false;
        cs.Bypass_Keys__c = null;
        upsert cs;
        System.assertEquals(true, AutomationBypass.bypassTriggers('TRG:Quote'), 'Flag should bypass triggers');

        // Keys should also work (case/space insensitive)
        cs = ensureUserSetting();
        cs.Bypass_Triggers__c = false;
        cs.Bypass_Keys__c = ' TRG:Quote ; FLOW:My_Flow ';
        upsert cs;
        System.assertEquals(true, AutomationBypass.bypassTriggers('TRG:Quote'), 'Key list should bypass trigger');
        System.assertEquals(true, AutomationBypass.bypassFlows('FLOW:MY_FLOW'), 'Key list should be case-insensitive for flows');
    }

    @IsTest
    static void persistent_expired_bypass_ignored() {
        reset();
        Automation_Bypass_Settings__c cs = ensureUserSetting();
        cs.Bypass_All__c = true;
        cs.Bypass_Expires_At__c = System.now().addMinutes(-5); // already expired
        upsert cs;
        System.assertEquals(false, AutomationBypass.bypassTriggers('TRG:Opportunity'), 'Expired setting should not bypass');
    }

    @IsTest
    static void transaction_bypass_key_and_all() {
        reset();
        // Key-based txn bypass
        AutomationBypass.enableTxn('TRG:Opportunity');
        System.assertEquals(true, AutomationBypass.bypassTriggers('TRG:Opportunity'), 'Txn key should bypass trigger');
        AutomationBypass.clearTxn();
        System.assertEquals(false, AutomationBypass.bypassTriggers('TRG:Opportunity'), 'Cleared txn should stop bypass');

        // All-txn bypass via guard auto-cleanup
        AutomationBypass.Guard g = AutomationBypass.enterAllTxn();
        try {
            System.assertEquals(true, AutomationBypass.bypassValidations('VR:Account:Rule'), 'All-txn bypass applies to validations');
        } finally {
            g.close();
        }
        System.assertEquals(false, AutomationBypass.bypassValidations('VR:Account:Rule'), 'Guard close should clear bypass');
    }

    @IsTest
    static void flow_action_respects_txn_and_settings() {
        reset();
        // Transaction path
        AutomationBypass.enableTxn('FLOW:Sample_Flow');
        AutomationBypassFlowAction.Request req = new AutomationBypassFlowAction.Request();
        req.key = 'FLOW:Sample_Flow';
        List<AutomationBypassFlowAction.Response> resp =
            AutomationBypassFlowAction.shouldBypass(new List<AutomationBypassFlowAction.Request>{req});
        System.assertEquals(true, resp[0].bypass, 'Txn bypass should be honored by invocable');

        // Settings path without txn
        AutomationBypass.clearTxn();
        Automation_Bypass_Settings__c cs = ensureUserSetting();
        cs.Bypass_Flows__c = true;
        cs.Bypass_All__c = false;
        cs.Bypass_Keys__c = null;
        upsert cs;
        resp = AutomationBypassFlowAction.shouldBypass(new List<AutomationBypassFlowAction.Request>{req});
        System.assertEquals(true, resp[0].bypass, 'Flow flag should be honored by invocable');
    }

    @IsTest
    static void guard_skips_opportunity_trigger_then_restores() {
        reset();

        // Guard should add/remove txn key cleanly
        AutomationBypass.Guard g = AutomationBypass.enterTxn(new Set<String>{'TRG:Opportunity'});
        System.assertEquals(true, AutomationBypass.bypassTriggers('TRG:Opportunity'), 'Guard should enable txn bypass');
        g.close();
        System.assertEquals(false, AutomationBypass.bypassTriggers('TRG:Opportunity'), 'Guard close should clear txn bypass');
    }
}