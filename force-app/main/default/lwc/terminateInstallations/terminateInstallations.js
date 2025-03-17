import { LightningElement, api, track } from 'lwc';
import terminateInstallationRecord from '@salesforce/apex/CreateInstallationsController.terminateSingleRecord';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class TerminateInstallations extends LightningElement
{
    openModal = true;
    @track tValue = '';
    @api recordId;
    @track hideFooter = false;
    @track message = '';
    options = [
        {label : 'Yes', value : 'Yes'},
        {label : 'No', value : 'No'}
    ];
    @track endDate;
    @track reason;
    @track showDetails = false;
    @track error = false;
    @track message = ''

    handleFieldChange(event)
    {
        let fieldValue = event.currentTarget.value;
        let fieldName = event.target.fieldName;
        let field = event.target;
        console.log('field --> ' + JSON.stringify(field));
        console.log(fieldName+' --> '+fieldValue);
        if(fieldName == 'Termination_End_Date__c')
        {
            this.endDate = fieldValue;
            let dateVal = new Date();
            let newDate = new Date(fieldValue);
            console.log('newDate --> ' + JSON.stringify(newDate));
            console.log('dateVal --> ' + JSON.stringify(dateVal));
            /*if(dateVal > newDate)
            {
                this.message = 'Date value must be less than today';
                this.error = true;
                field.setErrors('Date value must be less than today');
                field.reportValidity();
            }
            else
            {
                this.message = 'Date value must be less than today';
                this.error = false;
            }*/
        }
        else if(fieldName == 'Termination_Reason__c')
        {
            this.reason = fieldValue;
        }
    }

    handleSave(event)
    {
        if(!this.error)
        {
            if(this.tValue == 'Yes')
            {
                const allFieldsValid = [...this.template.querySelectorAll('lightning-input-field')].reduce(
                    (validSoFar, inputField) => {
                        return validSoFar && inputField.reportValidity();
                        },
                        true
                );
                if (allFieldsValid) {
                    terminateInstallationRecord({
                        instId : this.recordId,
                        endDate : this.endDate,
                        reason : this.reason
                    })
                    .then(result => {
                        if(result == 'SUCCESS')
                        {
                            console.log('result --> ' + JSON.stringify(result));
                            this.hideFooter = true;
                            this.message = 'Installation Terminated Successfully.';
                            const evt = new ShowToastEvent({
                                title: 'Success',
                                message: 'Installation Terminated Successfully.',
                                variant: 'success'
                            });
                            this.dispatchEvent(evt);
                            const closeEvent = new CloseActionScreenEvent();
                            this.dispatchEvent(closeEvent);
                        }
                    })
                    .catch(error => {
                        console.log('error --> ' + JSON.stringify(error));
                        this.hideFooter = true;
                        this.message = 'Error oocured while updating the Installation to Terminated.';
                        const evt = new ShowToastEvent({
                            title: 'Error',
                            message: 'Error oocured while updating the Installation to Terminated.',
                            variant: 'error'
                        });
                        this.dispatchEvent(evt);
                        const closeEvent = new CloseActionScreenEvent();
                        this.dispatchEvent(closeEvent);
                    });
                }
            }
            else
            {
                const closeEvent = new CloseActionScreenEvent();
                this.dispatchEvent(closeEvent);
            }
        }
    }

    onSelected(event)
    {
        console.log('value --> ' + event.target.value);
        this.tValue = event.target.value;
        console.log('tvalue --> ' + this.tValue);
        if(this.tValue == 'Yes')
        {
            this.showDetails = true;
        }
        else
        {
            this.showDetails = false;
        }
    }

    cancel(event)
    {
        const closeEvent = new CloseActionScreenEvent();
        this.dispatchEvent(closeEvent);
    }
}