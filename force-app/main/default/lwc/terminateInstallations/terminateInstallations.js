import { LightningElement, api, track, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import terminateInstallationRecord from '@salesforce/apex/CreateInstallationsController.terminateSingleRecord';
import getContractDates from '@salesforce/apex/CreateInstallationsController.getContractDetails';
import validateOpenItems from '@salesforce/apex/CreateInstallationsController.validateOpenQuotesOrders';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from "lightning/platformShowToastEvent";

const INSTALLATION_FIELDS = ['Installation__c.Contract__c'];

export default class TerminateInstallations extends LightningElement {
    @track tValue = '';
    @api recordId;
    @track showDetails = false;
    @track error = false;
    @track errorMessage = '';
    @track endDate;
    @track reason;
    @track disableSaveButton = true; // 🟢 Prevents interaction until validation completes
    @track warnings;
    @track isValidating = true;

    contractStartDate;
    contractEndDate;
    contractId;
    hasRunInitialValidation = false;

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

    get isSaveDisabled() {
        return this.disableSaveButton || this.isValidating;
    }

    get hasWarnings() {
        return Array.isArray(this.warnings) && this.warnings.length > 0;
    }

    get showTerminationForm() {
        return !this.isValidating && !this.hasWarnings;
    }

    @wire(getRecord, { recordId: '$recordId', fields: INSTALLATION_FIELDS })
    wiredInstallation({ data, error }) {
        if (data) {
            this.contractId = data.fields.Contract__c.value;
            if (!this.hasRunInitialValidation) {
                this.hasRunInitialValidation = true;
                this.validateBeforeTermination();
            }
        } else if (error) {
            console.error('Error fetching installation record:', JSON.stringify(error));
        }
    }

    formatWarningMessages(warnings) {
        if (!warnings || !Array.isArray(warnings)) {
            return null;
        }

        return warnings.map((warning) => {
            if (typeof warning !== 'string') {
                return warning;
            }

            if (warning.includes('<a ')) {
                return warning;
            }

            const primaryLinkPattern = /(Quote|Order)\s+([^\(]+?)\s+\(\/([a-zA-Z0-9]{15,18})\)/g;
            const withPrimaryLink = warning.replace(primaryLinkPattern, (_match, label, name, recordId) => {
                const href = `/${recordId}`;
                return `${label} <a href="${href}" target="_blank">${name.trim()}</a>`;
            });

            return withPrimaryLink.replace(/\(\/([a-zA-Z0-9]{15,18})\)/g, (_match, recordId) => {
                const href = `/${recordId}`;
                return `<a href="${href}" target="_blank">${href}</a>`;
            });
        });
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

                if (!allFieldsValid) {
                    return;
                }

                this.disableSaveButton = true; // 🔴 Disable button after clicking
                this.warnings = null;

                this.validateBeforeTermination(true);
            } else {
                this.closeAction();
            }
        }
    }

    validateBeforeTermination(proceedAfterValidation = false) {
        if (!this.contractId) {
            if (proceedAfterValidation) {
                this.proceedWithTermination();
            } else {
                this.disableSaveButton = false;
            }
            this.isValidating = false;
            return;
        }

        this.isValidating = true;
        validateOpenItems({ contractId: this.contractId })
            .then(result => {
                const formattedWarnings = this.formatWarningMessages(result);
                if (formattedWarnings && formattedWarnings.length > 0) {
                    this.warnings = formattedWarnings;
                    if (proceedAfterValidation) {
                        this.disableSaveButton = false;
                        this.showToast('Warning', 'Open Quotes or Orders must be activated before terminating this installation.', 'warning');
                    } else {
                        this.disableSaveButton = true;
                    }
                } else {
                    this.warnings = null;
                    if (proceedAfterValidation) {
                        this.proceedWithTermination();
                    } else {
                        this.disableSaveButton = false;
                    }
                }
            })
            .catch(error => {
                console.error('Error validating open quotes/orders:', JSON.stringify(error));
                this.showToast('Error', 'Unable to validate open Quotes/Orders. Please try again later.', 'error');
                this.disableSaveButton = false;
            })
            .finally(() => {
                this.isValidating = false;
            });
    }

    proceedWithTermination() {
        terminateInstallationRecord({
            instId: this.recordId,
            endDate: this.endDate,
            reason: this.reason
        })
            .then(result => {
                if (result === 'SUCCESS') {
                    this.showToast('Success', 'Installation Terminated Successfully.', 'success');
                    this.closeAction();
                } else {
                    this.disableSaveButton = false;
                    this.showToast('Error', 'Unable to terminate installation.', 'error');
                }
            })
            .catch(error => {
                console.error('Error:', JSON.stringify(error));
                this.disableSaveButton = false;
                this.showToast('Error', 'Error occurred while terminating the installation.', 'error');
                this.closeAction();
            });
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
        this.disableSaveButton = false;
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}