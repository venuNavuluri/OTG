import { LightningElement, api, track, wire } from 'lwc';
import terminateInstallationRecord from '@salesforce/apex/CreateInstallationsController.terminateSingleRecord';
import getContractDates from '@salesforce/apex/CreateInstallationsController.getContractDetails';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class TerminateInstallations extends LightningElement {
    @track tValue = '';
    @api recordId;
    @track showDetails = false;
    @track error = false;
    @track errorMessage = '';
    @track endDate;
    @track reason;
    @track disableSaveButton = false; // 🟢 Prevents multiple clicks

    contractStartDate;
    contractEndDate;

    options = [
        { label: 'Yes', value: 'Yes' },
        { label: 'No', value: 'No' }
    ];

    // 🟢 Fetch Contract Start & End Date from Apex
    @wire(getContractDates, { recordId: '$recordId' })
    wiredContractData({ error, data }) {
        if (data) {
            this.contractStartDate = new Date(data.startDate);
            this.contractEndDate = new Date(data.endDate);
        } else if (error) {
            console.error('Error fetching contract dates:', error);
        }
    }

    handleFieldChange(event) {
        let fieldName = event.target.fieldName;
        let fieldValue = event.currentTarget.value;

        if (fieldName === 'Termination_End_Date__c') {
            this.endDate = new Date(fieldValue);

            // 🟢 Validate Termination Date Against Contract Dates
            if (this.contractStartDate && this.contractEndDate) {
                if (this.endDate < this.contractStartDate || this.endDate > this.contractEndDate) {
                    this.error = true;
                    this.errorMessage = 'Termination date should be within the contracting period.';
                } else {
                    this.error = false;
                    this.errorMessage = '';
                }
            }
        } else if (fieldName === 'Termination_Reason__c') {
            this.reason = fieldValue;
        }
    }

    handleSave() {
        if (!this.error) {
            if (this.tValue === 'Yes') {
                const allFieldsValid = [...this.template.querySelectorAll('lightning-input-field')].reduce(
                    (validSoFar, inputField) => validSoFar && inputField.reportValidity(),
                    true
                );

                if (allFieldsValid) {
                    this.disableSaveButton = true; // 🔴 Disable button after clicking

                    terminateInstallationRecord({
                        instId: this.recordId,
                        endDate: this.endDate,
                        reason: this.reason
                    })
                        .then(result => {
                            if (result === 'SUCCESS') {
                                this.showToast('Success', 'Installation Terminated Successfully.', 'success');
                                this.closeAction();
                            }
                        })
                        .catch(error => {
                            console.error('Error:', JSON.stringify(error));
                            this.showToast('Error', 'Error occurred while terminating the installation.', 'error');
                            this.closeAction();
                        });
                }
            } else {
                this.closeAction();
            }
        }
    }

    onSelected(event) {
        this.tValue = event.target.value;
        this.showDetails = this.tValue === 'Yes';
    }

    cancel() {
        this.closeAction();
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(evt);
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}