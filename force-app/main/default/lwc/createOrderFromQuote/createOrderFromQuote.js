import { LightningElement, api, track } from 'lwc';
import quoteId from '@salesforce/schema/SBQQ__Quote__c.Id';
import quoteOrdered from '@salesforce/schema/SBQQ__Quote__c.SBQQ__Ordered__c';
import createOrderSuccessMsg from '@salesforce/label/c.CreateOrderSuccessMsg';
import createOrderMessage from '@salesforce/label/c.CreateOrderMessage';
import { CloseActionScreenEvent } from 'lightning/actions';
import updateQuoteToOrdered from '@salesforce/apex/CreateOrderFromQuoteController.updateQuoteToOrdered';

export default class CreateOrderFromQuote extends LightningElement
{
    @track createOrderMsg = true;
    @track message = createOrderMessage;
    @track success = false;
    @api recordId;

    createOrder()
    {
        console.log('lbl --> ' + JSON.stringify(createOrderMessage));
        /*const fields = {};
        fields[quoteId.Id] = this.recordId;
        fields[quoteOrdered.SBQQ__Ordered__c] = true;
        updateRecord({ fields });*/
        updateQuoteToOrdered({qtId:this.recordId})
        .then(result => {
            console.log('result --> ' + JSON.stringify(result));
            if(result == 'SUCCESS')
            {
                this.message = createOrderSuccessMsg;
                this.success = true;
            }
        })
        .catch(error => {
            console.log('error --> ' + error);
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