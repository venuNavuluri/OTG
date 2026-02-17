public with sharing class AutomationBypass {

    // ----------------------------
    // Transaction-scoped bypass
    // ----------------------------
    private static Boolean txnBypassAll = false;
    private static Set<String> txnKeys = new Set<String>();

    private static String norm(String key) {
        return String.isBlank(key) ? null : key.trim().toLowerCase();
    }

    // ----------------------------
    // Effective hierarchy settings
    // ----------------------------
    private static Automation_Bypass_Settings__c getEffectiveSettings() {
        Automation_Bypass_Settings__c cs = Automation_Bypass_Settings__c.getInstance(UserInfo.getUserId());
        if (cs == null) cs = Automation_Bypass_Settings__c.getOrgDefaults();
        return cs;
    }

    private static Boolean isExpired(Automation_Bypass_Settings__c cs) {
        if (cs == null) return true;
        if (cs.Bypass_Expires_At__c == null) return false; // no expiry means allowed until changed
        return cs.Bypass_Expires_At__c <= System.now();
    }

    private static Boolean keyInSetting(String key, String semicolonList) {
        String k = norm(key);
        if (k == null || String.isBlank(semicolonList)) return false;

        // Exact matching: wrap both sides in semicolons to avoid false positives
        String wrapped = ';' + semicolonList.toLowerCase().replace(' ', '') + ';';
        return wrapped.contains(';' + k.replace(' ', '') + ';');
    }

    // ----------------------------
    // Transaction API
    // ----------------------------
    public static void enableAllTxn() { txnBypassAll = true; }
    public static void disableAllTxn() { txnBypassAll = false; }

    public static void enableTxn(String key) {
        String k = norm(key);
        if (k != null) txnKeys.add(k);
    }

    public static void disableTxn(String key) {
        String k = norm(key);
        if (k != null) txnKeys.remove(k);
    }

    public static void clearTxn() {
        txnBypassAll = false;
        txnKeys.clear();
    }

    // ----------------------------
    // Public checks
    // ----------------------------
    public static Boolean bypassTriggers(String key) {
        if (txnBypassAll) return true;
        if (txnKeys.contains(norm(key))) return true;

        Automation_Bypass_Settings__c cs = getEffectiveSettings();
        if (cs == null) return false;

        // If you enabled expiry, expired bypass should not apply
        if (isExpired(cs)) {
            // Expired: ignore bypass flags, except txn bypass
            return false;
        }

        if (cs.Bypass_All__c) return true;
        if (cs.Bypass_Triggers__c) return true;
        return keyInSetting(key, cs.Bypass_Keys__c);
    }

    public static Boolean bypassFlows(String flowKey) {
        if (txnBypassAll) return true;
        if (txnKeys.contains(norm(flowKey))) return true;

        Automation_Bypass_Settings__c cs = getEffectiveSettings();
        if (cs == null) return false;

        if (isExpired(cs)) return false;

        if (cs.Bypass_All__c) return true;
        if (cs.Bypass_Flows__c) return true;
        return keyInSetting(flowKey, cs.Bypass_Keys__c);
    }

    public static Boolean bypassValidations(String validationKey) {
        if (txnBypassAll) return true;
        if (txnKeys.contains(norm(validationKey))) return true;

        Automation_Bypass_Settings__c cs = getEffectiveSettings();
        if (cs == null) return false;

        if (isExpired(cs)) return false;

        if (cs.Bypass_All__c) return true;
        if (cs.Bypass_Validations__c) return true;
        return keyInSetting(validationKey, cs.Bypass_Keys__c);
    }

    // ----------------------------
    // Guard (auto cleanup pattern)
    // ----------------------------
    public class Guard {
        private Set<String> keysAdded = new Set<String>();
        private Boolean allAdded = false;

        private Guard() {}

        public void close() {
            for (String k : keysAdded) {
                AutomationBypass.disableTxn(k);
            }
            if (allAdded) {
                AutomationBypass.disableAllTxn();
            }
        }
    }

    public static Guard enterTxn(Set<String> keys) {
        Guard g = new Guard();
        if (keys != null) {
            for (String k : keys) {
                String nk = norm(k);
                if (nk == null) continue;
                enableTxn(nk);
                g.keysAdded.add(nk);
            }
        }
        return g;
    }

    public static Guard enterAllTxn() {
        Guard g = new Guard();
        enableAllTxn();
        g.allAdded = true;
        return g;
    }
}