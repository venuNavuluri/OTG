public with sharing class AccountTriggerHandler {
    private static Boolean isExecuting = false;

    public static void beforeInsert(List<Account> newList) {
        if (start()) {
            try {
            } finally {
                stop();
            }
        }
    }

    public static void beforeUpdate(List<Account> newList, Map<Id, Account> oldMap) {
        if (start()) {
            try {
            } finally {
                stop();
            }
        }
    }

    public static void beforeDelete(List<Account> oldList) {
        if (start()) {
            try {
            } finally {
                stop();
            }
        }
    }

    public static void afterInsert(List<Account> newList) {
        if (start()) {
            try {
            } finally {
                stop();
            }
        }
    }

    public static void afterUpdate(List<Account> newList, Map<Id, Account> oldMap) {
        if (start()) {
            try {
                AccountChildOpportunitySyncService.afterAccountUpdate(newList, oldMap);
            } finally {
                stop();
            }
        }
    }

    public static void afterDelete(List<Account> oldList) {
        if (start()) {
            try {
            } finally {
                stop();
            }
        }
    }

    public static void afterUndelete(List<Account> newList) {
        if (start()) {
            try {
            } finally {
                stop();
            }
        }
    }

    private static Boolean start() {
        if (isExecuting) {
            return false;
        }
        isExecuting = true;
        return true;
    }

    private static void stop() {
        isExecuting = false;
    }
}
