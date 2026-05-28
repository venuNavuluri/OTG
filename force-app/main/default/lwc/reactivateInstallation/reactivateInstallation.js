import { LightningElement, api, track } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { RefreshEvent } from 'lightning/refresh';

import cancelFutureTermination from '@salesforce/apex/FutureTermCancelService.cancelFutureTermination';

export default class ReactivateInstallation extends LightningElement {
    @api recordId;
    @track showSpinner = false;

    handleReactivate() {
        this.showSpinner = true;

        cancelFutureTermination({ installationId: this.recordId })
            .then(() => {
                this.showToast('Success', 'Future termination cancelled successfully.', 'success');
                this.dispatchEvent(new RefreshEvent());
                this.close();
            })
            .catch(error => {
                const message = error?.body?.message || error.message || 'Unable to cancel future termination.';
                console.error('Error:', message);
                this.showToast('Error', message, 'error');
                this.close();
            })
            .finally(() => {
                this.showSpinner = false;
            });
    }

    close() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant,
                mode: 'dismissable'
            })
        );
    }
}
