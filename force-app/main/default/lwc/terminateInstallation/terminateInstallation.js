import { api, LightningElement } from 'lwc';

import INSTALLATION_OBJECT from "@salesforce/schema/Installation__c";

import ID_FIELD from "@salesforce/schema/Installation__c.Id";
import STATUS_FIELD from "@salesforce/schema/Installation__c.Installation_Order_Status__c";
import Term_End_Date_FIELD from "@salesforce/schema/Installation__c.Termination_End_Date__c";
import Term_Reason_FIELD from "@salesforce/schema/Installation__c.Termination_Reason__c";

import { updateRecord } from 'lightning/uiRecordApi';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class TerminateInstallation extends LightningElement {
    @api recordId;
    isConfirmed = false;

    onConfirmation(event)
    {
        const fields = {};
        fields[ID_FIELD.fieldApiName] = this.recordId;
        fields[STATUS_FIELD.fieldApiName] = 'Terminated';
        fields[Term_End_Date_FIELD.fieldApiName] = new Date().toISOString();//(new Date().getMonth()  + 1) + '-' + new Date().getDate() + '-' + new Date().getFullYear();
        console.log('date --> ' + JSON.stringify(new Date()));
        fields[Term_Reason_FIELD.fieldApiName] = 'Terminated Instantly';

        const recordData = {
            fields : fields
        };

        updateRecord(recordData).then(record => {
            console.log('record --> ' + JSON.stringify(record));
            const toast = new ShowToastEvent({
                title : 'Success',
                message : 'Installation has been Terminated.',
                variant : 'success'
            });
            this.dispatchEvent(toast);
            this.dispatchEvent(new CloseActionScreenEvent());
        }).catch(error => {
            console.log('error -->' + JSON.stringify(error));
            const toast = new ShowToastEvent({
                title : 'Error',
                message : 'Error occured while updating the Installation to Terminated.',
                variant : 'error'
            });
            this.dispatchEvent(toast);
            this.dispatchEvent(new CloseActionScreenEvent());
        })
    }

    closeModal(event)
    {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}