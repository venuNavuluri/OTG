import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';
import Toast from 'lightning/toast';

import requestTermination from '@salesforce/apex/ContractTerminationController.requestTermination';

const CONTRACT_FIELDS = ['Contract.StartDate', 'Contract.EndDate', 'Contract.Status'];

export default class TerminateContract extends LightningElement {
    @api recordId;

    contractStartDate;
    contractEndDate;
    contractStatus;

    confirmationValue = '';
    terminationDate;
    lostReason;
    lostReasonComments;
    dateErrorMessage = '';
    isLoading = true;
    isSaving = false;

    @wire(getRecord, { recordId: '$recordId', fields: CONTRACT_FIELDS })
    wiredContract({ data, error }) {
        if (data) {
            this.contractStartDate = this.normalizeDateValue(data.fields.StartDate.value);
            this.contractEndDate = this.normalizeDateValue(data.fields.EndDate.value);
            this.contractStatus = data.fields.Status.value;
            this.isLoading = false;
        } else if (error) {
            // The quick action cannot proceed without the contract record.
            this.showToast('Error', 'Unable to load contract details.', 'error');
            this.closeAction();
        }
    }

    get isReady() {
        return !this.isLoading;
    }

    get isYesSelected() {
        return this.confirmationValue === 'Yes';
    }

    get isNoSelected() {
        return this.confirmationValue === 'No';
    }

    get showDetails() {
        return this.isYesSelected;
    }

    get hasDateError() {
        return Boolean(this.dateErrorMessage);
    }

    get isSaveDisabled() {
        if (this.isLoading || this.isSaving || !this.confirmationValue) {
            return true;
        }
        if (this.isNoSelected) {
            return false;
        }
        return this.hasDateError || !this.terminationDate || !this.lostReason || !this.lostReasonComments?.trim();
    }

    normalizeDateValue(value) {
        return value ? String(value).slice(0, 10) : null;
    }

    handleSelection(event) {
        this.confirmationValue = event.target.value;
    }

    handleTerminationDateChange(event) {
        this.terminationDate = this.normalizeDateValue(event.target.value);
        this.dateErrorMessage = '';

        if (!this.terminationDate || !this.contractStartDate || !this.contractEndDate) {
            return;
        }

        if (this.terminationDate < this.contractStartDate || this.terminationDate > this.contractEndDate) {
            this.dateErrorMessage = 'Termination date should be within the contracting period.';
        }
    }

    handleFieldChange(event) {
        if (event.target.fieldName === 'Lost_Reason__c') {
            this.lostReason = event.detail?.value;
        } else if (event.target.fieldName === 'Lost_Reason_Comments__c') {
            this.lostReasonComments = event.detail?.value;
        }
    }

    handleSave() {
        if (this.isNoSelected) {
            this.closeAction();
            return;
        }

        if (!this.isYesSelected) {
            this.showToast('Warning', 'Please confirm whether you want to terminate the contract.', 'warning');
            return;
        }

        if (this.contractStatus === 'Terminated') {
            this.showToast('Warning', 'This contract is already terminated.', 'warning');
            return;
        }

        const inputs = [...this.template.querySelectorAll('lightning-input, lightning-input-field')];
        const allFieldsValid = inputs.reduce((isValid, inputCmp) => {
            return isValid && inputCmp.reportValidity();
        }, true);
        if (!allFieldsValid || this.hasDateError) {
            return;
        }

        this.isSaving = true;
        requestTermination({
            contractId: this.recordId,
            terminationDate: this.terminationDate,
            lostReason: this.lostReason,
            lostReasonComments: this.lostReasonComments
        })
            .then(() => {
                this.showToast(
                    'Success',
                    'Contract termination submitted. Related installations and sales orders will be processed asynchronously.',
                    'success'
                );
                this.dispatchEvent(new RefreshEvent());
                this.closeAction();
            })
            .catch((error) => {
                const message = error?.body?.message || 'Unable to terminate contract.';
                this.showToast('Error', message, 'error');
                this.isSaving = false;
            });
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
        this.isSaving = false;
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}
