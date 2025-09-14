import { LightningElement, api, track } from 'lwc';
import activate from '@salesforce/apex/ActivateInstallationController.activateInstallation';
import getContractDetails from '@salesforce/apex/CreateInstallationsController.getContractDetails';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ActivateInstallation extends LightningElement {
    @api recordId;
    @track startDate;
    @track showSpinner = false;

    updateFieldValue(event) {
        this.startDate = event.target.value;
    }

    activateInstallationRecord() {
        if (!this.startDate) {
            this.showToast('Validation Error', 'Please enter Installation Start Date.', 'error');
            return;
        }
    
        this.showSpinner = true;
    
        getContractDetails({ recordId: this.recordId })
            .then(result => {
                const enteredDate = new Date(this.startDate);
                const contractStart = new Date(result.startDate);
                const contractEnd = new Date(result.endDate);
                const contractStatus = result.status;
    
                if (contractStatus !== 'Activated') {
                    throw new Error('Contract must be in Activated status before activating the installation.');
                }
    
                if (enteredDate < contractStart || enteredDate > contractEnd) {
                    throw new Error(`Start Date must be between ${contractStart.toLocaleDateString()} and ${contractEnd.toLocaleDateString()}.`);
                }
    
                // 🔁 Return activation promise so we can chain
                return activate({
                    recId: this.recordId,
                    startDate: this.startDate
                });
            })
            .then(result => {
                if (result === 'SUCCESS') {
                    this.showToast('Success', 'Installation activated successfully.', 'success');
                } else {
                    this.showToast('Error', `Unexpected result: ${result}`, 'error');
                }
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch(error => {
                const message = error?.body?.message || error.message || 'Something went wrong during activation.';
                console.error('Error:', message);
                this.showToast('Error', message, 'error');
                this.dispatchEvent(new CloseActionScreenEvent());
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