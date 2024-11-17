import { LightningElement, api, track } from 'lwc';
import { getRecord } from "lightning/uiRecordApi";
import activate from '@salesforce/apex/ActivateOrderController.activateOrder';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
const FIELDS = ['Name','SBQQ__Account__c','SBQQ__Opportunity2__c'];

export default class ActivateOrder extends LightningElement
{
    @api recordId;
    @track message;
    @track showMessage;

    createContract(event)
    {
        console.log('ordId --> ' + this.recordId);
        activate({ordId : this.recordId}).then(result => {
            console.log('result --> ' + result);
            if(result == 'SUCCESS')
            {
                /*this.message = 'Quote activated Successfully';
                this.showMessage = true;*/
                const event = new ShowToastEvent({
                    title: 'Success',
                    message: 'Contract Created Successfully.',
                    variant: 'success',
                    mode: 'dismissable'
                });
                //setTimeout(this.dispatchEvent(event), 500);
                this.dispatchEvent(new CloseActionScreenEvent());
            }
        }).catch(error => {
            console.log('error --> ' + JSON.stringify(error));
            /*this.message = 'Error occured activating Quote. Please contact the Technical support team for more details.';
            this.showMessage = true;*/
            const event = new ShowToastEvent({
                title: 'Failed',
                message: 'Error occured while creating contract.',
                variant: 'error',
                mode: 'dismissable'
            });
            //setTimeout(this.dispatchEvent(event), 500);
            this.dispatchEvent(new CloseActionScreenEvent());
        });
    }

    close(event)
    {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}