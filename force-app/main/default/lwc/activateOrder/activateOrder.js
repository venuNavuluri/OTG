import { api, LightningElement, track } from 'lwc';
import { updateRecord } from 'lightning/uiRecordApi';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getOpportunityId from '@salesforce/apex/OrderTriggerHandler.getOpportunityId';

export default class ActivateOrder extends LightningElement {
    @api recordId;
    @track showSpinner = false;

    createContract() {
        this.showSpinner = true;

        getOpportunityId({ orderId: this.recordId })
            .then(result => {
                const oppId = result.opportunityId;
                const orderType = result.orderType;
                
                // Skip opportunity update for Service Delivery orders
                if (orderType !== 'Service Delivery') {
                    if (!oppId) {
                        throw new Error('No Opportunity linked to this Order.');
                    }
                    
                    return updateRecord({
                        fields: {
                            Id: oppId,
                            StageName: 'Completed'
                        }
                    }).then(() => {
                        return this.updateOrder();
                    });
                } else {
                    return this.updateOrder();
                }
            })
            .then(() => {
                this.showSuccess();
            })
            .catch(error => {
                this.handleError(error);
            });
    }

    updateOrder() {
        return updateRecord({
            fields: {
                Id: this.recordId,
                Status: 'Activated',
                Is_Activated__c: true,
                SBQQ__Contracted__c: true
            }
        });
    }

    showSuccess() {
        this.showSpinner = false;
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Order activated successfully' + 
                         (this.orderType !== 'Service Delivery' ? ' and Opportunity completed' : ''),
                variant: 'success'
            })
        );
        this.dispatchEvent(new CloseActionScreenEvent());
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

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Validation Error',
                message: errorMessage,
                variant: 'error',
                mode: 'sticky'
            })
        );
    }

    close() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}