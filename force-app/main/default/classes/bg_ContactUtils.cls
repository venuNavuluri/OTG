/*****************************************************************
 * bg_ContactUtils
 *
 * Utils class for Contact object
 * 
 * Test class: bg_ContactUtils_Test
 *
 * Author: Dawid Lominski
 * Created: 12-10-2021
 * 
 * Edited: 24-11-2021 - Added filter to allow Contact to be InActive if  Opp is Closed Lost/Closed Won/Completed
******************************************************************/

public with sharing class bg_ContactUtils {
    public static void inactiveContactOnOpps(List<Contact> updatedContacts) {

        List<Id> contactIds = new List<Id>();

        for(Contact con : updatedContacts) {
            contactIds.add(con.Id);
        }

        Set<Id> contactsWithOpenOpps = new Set<Id>();

        for (Opportunity OpenOpp : [SELECT Id, Contact_Name__c, StageName FROM Opportunity WHERE Contact_Name__c IN :contactIds AND StageName != 'Closed Lost' AND StageName != 'Closed Won' AND StageName != 'Completed']){
            contactsWithOpenOpps.add(OpenOpp.Contact_Name__c);
        }

        for(Contact cont : updatedContacts) {
            if(contactsWithOpenOpps.contains(cont.Id)){
                cont.addError('You cannot make a contact inactive when it is linked to an open Opportunity');
                break;
            }
        }
    }
}