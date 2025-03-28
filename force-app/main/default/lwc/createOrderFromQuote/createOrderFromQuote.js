import { LightningElement, api, track, wire } from 'lwc';
import quoteId from '@salesforce/schema/SBQQ__Quote__c.Id';
import quoteOrdered from '@salesforce/schema/SBQQ__Quote__c.SBQQ__Ordered__c';
import createOrderSuccessMsg from '@salesforce/label/c.CreateOrderSuccessMsg';
import createOrderMessage from '@salesforce/label/c.CreateOrderMessage';
import { CloseActionScreenEvent } from 'lightning/actions';
import updateQuoteToOrdered from '@salesforce/apex/CreateOrderFromQuoteController.updateQuoteToOrdered';
import validateInstallationCount from '@salesforce/apex/CreateOrderFromQuoteController.validateInstallationCount';
import { getRecord } from 'lightning/uiRecordApi';

export default class CreateOrderFromQuote extends LightningElement
{
    @track createOrderMsg = true;
    @track message = '';//createOrderMessage;
    @track success = true;
    @api recordId;
    @track showSpinner = false;

    @wire(validateInstallationCount, { qtId : '$recordId'})
    valMsg({error, data}){
        console.log('data --> ' + JSON.stringify(data));
        console.log('error --> ' + JSON.stringify(error));
        if(data)
        {
            if(data != 'SUCCESS')
            {
                this.message = data;
                this.success = true;
            }
            else
            {
                this.message = createOrderMessage;
                this.success = false;
            }
        }
        else if (error)
        {
            this.message = error;
            this.success = true;
        }
    };
    /*connectedCallback()
    {
        validateInstallationCount({
            qtId : this.recordId
        }).then(result => {
            console.log('result1 --> ' + result);
            if(result != 'SUCCESS')
            {
                this.message = result;
                this.success = true;
            }
        }).catch(error => {
            console.log('error --> ' + JSON.stringify(error));
            this.success = true;
        })
    }*/
    createOrder()
    {
        this.showSpinner = true;
        console.log('lbl --> ' + JSON.stringify(createOrderMessage));
        /*const fields = {};
        fields[quoteId.Id] = this.recordId;
        fields[quoteOrdered.SBQQ__Ordered__c] = true;
        updateRecord({ fields });*/
        updateQuoteToOrdered({qtId:this.recordId})
        .then(result => {
            this.showSpinner = false;
            console.log('result --> ' + JSON.stringify(result));
            if(result == 'SUCCESS')
            {
                this.message = createOrderSuccessMsg;
                this.success = true;
            }
        })
        .catch(error => {
            this.showSpinner = false;
            console.log('error --> ' + JSON.stringify(error));
            this.message = JSON.stringify('Error occured while creating quote, please contact Technical support team.');
            this.success = true;
        })
        
    }

    closeModal()
    {
        this.createOrderMsg = false;
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}