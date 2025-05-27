import { LightningElement, api, track } from 'lwc';
import activate from '@salesforce/apex/ActivateInstallationController.activateInstallation';
import getContractDates from '@salesforce/apex/CreateInstallationsController.getContractDates';
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

        getContractDates({ recordId: this.recordId })
            .then(result => {
                const enteredDate = new Date(this.startDate);
                const contractStart = new Date(result.startDate);
                const contractEnd = new Date(result.endDate);

                if (enteredDate < contractStart || enteredDate > contractEnd) {
                    this.showToast(
                        'Validation Error',
                        `Start Date must be between ${contractStart.toLocaleDateString()} and ${contractEnd.toLocaleDateString()}.`,
                        'error'
                    );
                    this.showSpinner = false;
                    return;
                }

                // Proceed with activation
                return activate({
                    recId: this.recordId,
                    startDate: this.startDate
                });
            })
            .then(result => {
                if (result === 'SUCCESS') {
                    this.showToast('Success', 'Installation activated successfully.', 'success');
                    this.dispatchEvent(new CloseActionScreenEvent());
                }
            })
            .catch(error => {
                console.error('Error:', error);
                this.showToast('Error', 'Something went wrong during activation.', 'error');
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