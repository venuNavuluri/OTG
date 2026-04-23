@IsTest
public class AutomationBypassTestUtil {

    public static void enableForRunningUser(Boolean all, Boolean triggers, Boolean flows, Boolean validations, String keys, Datetime expiresAt, String reason) {
        upsert new Automation_Bypass_Settings__c(
            SetupOwnerId = UserInfo.getUserId(),
            Bypass_All__c = all,
            Bypass_Triggers__c = triggers,
            Bypass_Flows__c = flows,
            Bypass_Validations__c = validations,
            Bypass_Keys__c = keys,
            Bypass_Expires_At__c = expiresAt,
            Bypass_Reason__c = reason
        );
    }

    public static void disableForRunningUser() {
        Automation_Bypass_Settings__c cs = Automation_Bypass_Settings__c.getInstance(UserInfo.getUserId());
        if (cs != null) {
            cs.Bypass_All__c = false;
            cs.Bypass_Triggers__c = false;
            cs.Bypass_Flows__c = false;
            cs.Bypass_Validations__c = false;
            cs.Bypass_Keys__c = null;
            cs.Bypass_Expires_At__c = null;
            cs.Bypass_Reason__c = null;
            update cs;
        }
        AutomationBypass.clearTxn();
    }
}