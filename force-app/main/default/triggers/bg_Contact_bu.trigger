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