import { api, LightningElement, track } from 'lwc';
import { updateRecord } from 'lightning/uiRecordApi';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ActivateOrder extends LightningElement{
    @api recordId;
        @track showSpinner = false;
        
        createContract()
        {
            this.showSpinner = true;
            updateRecord({
                fields : {
                Id : this.recordId,
                Status : 'Activated',
                Is_Activated__c : true,
                SBQQ__Contracted__c : true,
                } 
            }).then(result => {
                this.showSpinner = false;
                this.showSpinner = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Order Activated Successfully',
                        variant: 'success'
                    })
                );
                console.log('result --> ' + JSON.stringify(result));
                this.dispatchEvent(new CloseActionScreenEvent());

            }).catch(error => {
                this.showSpinner = false;
                console.log('error --> ' + JSON.stringify(error));
                this.dispatchEvent(new CloseActionScreenEvent());
                
                // Extract validation rule message
                let errorMessage = 'An error occurred while Activating the Service Delivery Order';
                
                if (error.body?.output?.errors) {
                    errorMessage = error.body.output.errors.map(err => err.message).join('. ');
                } 
                else if (error.body?.pageErrors) {
                    errorMessage = error.body.pageErrors.map(err => err.message).join('. ');
                }
                else if (error.body?.message) {
                    errorMessage = error.body.message;
                }
                
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: errorMessage,
                        variant: 'error',
                        mode: 'sticky'
                    })
                );
            });
        }

        close(event)
        {
            this.dispatchEvent(new CloseActionScreenEvent());
        }
}