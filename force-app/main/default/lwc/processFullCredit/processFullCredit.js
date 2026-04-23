import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import processFullCredit from '@salesforce/apex/SalesOrderFullCreditController.processFullCredit';

export default class ProcessFullCredit extends NavigationMixin(LightningElement) {
    @api recordId;
    isProcessing = false;
    showConfirmation = true;

    handleProcess() {
        this.isProcessing = true;

        processFullCredit({ salesOrderId: this.recordId })
            .then((creditOrderId) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Full Credit Processed',
                        message: 'Credit note sales order created successfully.',
                        variant: 'success'
                    })
                );

                this.dispatchEvent(new CloseActionScreenEvent());

                if (creditOrderId) {
                    this[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: creditOrderId,
                            objectApiName: 'Sales_Order__c',
                            actionName: 'view'
                        }
                    });
                }
            })
            .catch((error) => {
                const message =
                    error?.body?.message || 'An error occurred while processing the full credit.';

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message,
                        variant: 'error'
                    })
                );
                this.isProcessing = false;
            });
    }

    closeModal() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}