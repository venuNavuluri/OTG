import { api, LightningElement, track } from 'lwc';
import { updateRecord } from 'lightning/uiRecordApi';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class CreateContract extends LightningElement {
    @api recordId;
    @track showSpinner = false;
    
    createContract()
    {
        this.showSpinner = true;
        updateRecord({fields : {
            Id : this.recordId,
            Status : 'Activated',
            Is_Activated__c : true,
            SBQQ__Contracted__c : true,
        }}).then(result => {
            this.showSpinner = false;
            console.log('result --> ' + JSON.stringify(result));
            this.dispatchEvent(new CloseActionScreenEvent());
        }).catch(error => {
            this.showSpinner = false;
            console.log('error --> ' + JSON.stringify(error));
            this.dispatchEvent(new CloseActionScreenEvent());
        })
    }

    close(event)
    {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}