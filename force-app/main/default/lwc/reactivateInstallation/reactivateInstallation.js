import { LightningElement, api, track } from 'lwc';
import { updateRecord } from 'lightning/uiRecordApi';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import ID_FIELD from '@salesforce/schema/Installation__c.Id';
import STATUS_FIELD from '@salesforce/schema/Installation__c.Installation_Order_Status__c';
import TERM_END_FIELD from '@salesforce/schema/Installation__c.Termination_End_Date__c';
import TERM_REASON_FIELD from '@salesforce/schema/Installation__c.Termination_Reason__c';

export default class ReactivateInstallation extends LightningElement {
    @api recordId;
    @track showSpinner = false;

    handleReactivate() {
        this.showSpinner = true;

        const fields = {};
        fields[ID_FIELD.fieldApiName] = this.recordId;
        fields[STATUS_FIELD.fieldApiName] = 'Active';
        fields[TERM_END_FIELD.fieldApiName] = null;
        fields[TERM_REASON_FIELD.fieldApiName] = null;

        updateRecord({ fields })
            .then(() => {
                this.showToast('Success', 'Future termination cancelled successfully.', 'success');
                this.close();
            })
            .catch(error => {
                const message = error?.body?.message || error.message || 'Unable to cancel future termination.';
                console.error('Error:', message);
                this.showToast('Error', message, 'error');
                this.close();
            })
            .finally(() => {
                this.showSpinner = false;
            });
    }

    close() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant,
                mode: 'dismissable'
            })
        );
    }
}