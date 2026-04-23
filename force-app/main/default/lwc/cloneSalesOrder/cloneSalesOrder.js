import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import cloneSalesOrder from '@salesforce/apex/SalesOrderCloneController.cloneSalesOrder';

export default class CloneSalesOrder extends NavigationMixin(LightningElement) {
    @api recordId;
    isProcessing = false;

    handleClone() {
        this.isProcessing = true;

        cloneSalesOrder({ salesOrderId: this.recordId })
            .then((clonedOrderId) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Sales Order Cloned',
                        message: 'Sales order and related items cloned successfully.',
                        variant: 'success'
                    })
                );

                this.dispatchEvent(new CloseActionScreenEvent());

                if (clonedOrderId) {
                    this[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: clonedOrderId,
                            objectApiName: 'Sales_Order__c',
                            actionName: 'view'
                        }
                    });
                }
            })
            .catch((error) => {
                const message =
                    error?.body?.message || 'An error occurred while cloning the sales order.';

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