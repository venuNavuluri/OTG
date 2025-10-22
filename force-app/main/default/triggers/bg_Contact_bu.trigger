/*****************************************************************
 * bg_Contact_bu
 *
 * Before update for Contact object
 * 
 *
 * Author: Dawid Lominski
 * Created: 12-10-2021
******************************************************************/

trigger bg_Contact_bu on Contact (before update) {

    VRConfiguration__c bypassTrig = VRConfiguration__c.getInstance();
    if (bypassTrig != null && bypassTrig.ByPass_Contact_Triggers__c) {
        System.debug('bg_Contact_bu Trigger skipped for user: ');
        return;
    }

    List<Contact> inactiveContactChange = new List<Contact>();

    for(Contact con : Trigger.new) {
        if(con.Inactive__c == true && Trigger.oldMap.get(con.Id).Inactive__c != con.Inactive__c) {
            inactiveContactChange.add(con);
        }
    }

    if(!inactiveContactChange.isEmpty()) {
        bg_ContactUtils.inactiveContactOnOpps(inactiveContactChange);
    }
}