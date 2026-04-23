import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';
import Toast from 'lightning/toast';

import terminateInstallationRecord from '@salesforce/apex/CreateInstallationsController.terminateSingleRecord';
import getContractDates from '@salesforce/apex/CreateInstallationsController.getContractDetails';
import validateOpenItems from '@salesforce/apex/CreateInstallationsController.validateOpenQuotesOrders';

const INSTALLATION_FIELDS = ['Installation__c.Contract__c'];

export default class TerminateInstallations extends LightningElement {
    @api recordId;

    tValue = '';
    showDetails = false;
    error = false;
    errorMessage = '';
    endDate;
    reason;
    disableSaveButton = true;
    warnings;
    isValidating = true;

    contractStartDate;
    contractEndDate;
    contractId;
    hasRunInitialValidation = false;

    @wire(getContractDates, { recordId: '$recordId' })
    wiredContractData({ error, data }) {
        if (data) {
            this.contractStartDate = this.normalizeDateValue(data.startDate);
            this.contractEndDate = this.normalizeDateValue(data.endDate);
        } else if (error) {
            console.error('Error fetching contract dates:', error);
        }
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

    get isSaveDisabled() {
        return this.disableSaveButton || this.isValidating;
    }

    get hasWarnings() {
        return Array.isArray(this.warnings) && this.warnings.length > 0;
    }

    get showTerminationForm() {
        return !this.isValidating && !this.hasWarnings;
    }

    get isYesSelected() {
        return this.tValue === 'Yes';
    }

    get isNoSelected() {
        return this.tValue === 'No';
    }

    normalizeDateValue(value) {
        return value ? String(value).slice(0, 10) : null;
    }

    formatWarningMessages(warnings) {
        if (!warnings || !Array.isArray(warnings)) {
            return null;
        }

        return warnings.map((warning) => {
            if (typeof warning !== 'string' || warning.includes('<a ')) {
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
        const fieldName = event.target.fieldName;
        const fieldValue = event.detail?.value ?? event.target.value;

        if (fieldName === 'Termination_End_Date__c') {
            this.endDate = this.normalizeDateValue(fieldValue);

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
        if (this.tValue === 'No') {
            this.closeAction();
            return;
        }

        if (this.tValue !== 'Yes') {
            this.showToast('Warning', 'Please confirm whether you want to terminate the installation.', 'warning');
            return;
        }

        if (this.error) {
            return;
        }

        const inputFields = [...this.template.querySelectorAll('lightning-input-field')];
        const allFieldsValid = inputFields.reduce(
            (validSoFar, inputField) => validSoFar && inputField.reportValidity(),
            true
        );

        const hasRequiredValues = Boolean(this.endDate) && Boolean(this.reason?.trim());

        if (!allFieldsValid || !hasRequiredValues) {
            inputFields.forEach((inputField) => inputField.reportValidity());
            return;
        }

        this.disableSaveButton = true;
        this.warnings = null;
        this.validateBeforeTermination(true);
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
            .then((result) => {
                const formattedWarnings = this.formatWarningMessages(result);
                if (formattedWarnings?.length) {
                    this.warnings = formattedWarnings;
                    if (proceedAfterValidation) {
                        this.disableSaveButton = false;
                        this.showToast(
                            'Warning',
                            'Open Quotes or Orders must be activated before terminating this installation.',
                            'warning'
                        );
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
            .catch((error) => {
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
            .then((result) => {
                if (result === 'SUCCESS') {
                    this.showToast('Success', 'Installation updated successfully.', 'success');
                    this.dispatchEvent(new RefreshEvent());
                    this.closeAction();
                } else {
                    this.disableSaveButton = false;
                    this.showToast('Error', 'Unable to terminate installation.', 'error');
                }
            })
            .catch((error) => {
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
        Toast.show(
            {
                label: title,
                message,
                variant
            },
            this
        );
    }

    closeAction() {
        this.disableSaveButton = false;
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}
