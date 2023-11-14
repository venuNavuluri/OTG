import { LightningElement, api, track } from 'lwc';
import { getRecord } from "lightning/uiRecordApi";
import activate from '@salesforce/apex/ActivateOrderController.activateQuote';
const FIELDS = ['Name','SBQQ__Account__c','SBQQ__Opportunity2__c'];

export default class ActivateQuote extends LightningElement
{
    @api recordId;
    @track message;
    @track showMessage;

    activate(event)
    {
        activate({quoteId : this.recordId}).then(result => {
            if(result == 'SUCCESS')
            {
                this.message = 'Quote activated Successfully';
                this.showMessage = true;
            }
        }).catch(error => {
            this.message = 'Error occured activating Quote. Please contact the Technical support team for more details.';
            this.showMessage = true;
        });
    }
}