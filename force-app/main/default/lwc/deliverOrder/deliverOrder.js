import { api, LightningElement, track } from 'lwc';
import { updateRecord } from 'lightning/uiRecordApi';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class DeliverOrder extends LightningElement {
    @api recordId;
    @track showSpinner = false;

    deliverOrder() {
        this.showSpinner = true;
        
        //update to Delivered
        this.updateOrder('Delivered')
            .then(() => {
                
                //After 5 sec, try to activate
                setTimeout(() => {
                    this.activateOrder();
                }, 5000);
            })
            .catch(error => {
                this.handleError(error);
            });
    }

    updateOrder(newStatus) {
        return updateRecord({
            fields: {
                Id: this.recordId,
                Status: newStatus
            }
        });
    }

    activateOrder() {
        this.showSpinner = true;
        this.updateOrder('Activated')
            .then(() => {
                this.showSpinner = false;
                this.showToast('Success', 'Order Delivered And Activated successfully', 'success');
                this.dispatchEvent(new CloseActionScreenEvent()); 
            })
            .catch(error => {
                this.handleError(error); 
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant,
                mode: variant === 'error' ? 'sticky' : 'dismissable'
            })
        );
    }

    handleError(error) {
        this.showSpinner = false;
        let errorMessage = 'An error occurred while updating the record.';
        if (error.body?.output?.errors?.length) {
            errorMessage = error.body.output.errors.map(e => e.message).join(' ');
        } else if (error.body?.pageErrors?.length) {
            errorMessage = error.body.pageErrors.map(e => e.message).join(' ');
        } else if (error.body?.message) {
            errorMessage = error.body.message;
        } else if (error.message) {
            errorMessage = error.message;
        }

        this.showToast('Validation Error', errorMessage, 'error');
    }

    close() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}