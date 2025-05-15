import { LightningElement, api, track } from 'lwc';
import createRecords from '@salesforce/apex/CreateSalesOrders.createSORecordsInst';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class CreateSOFromInstallation extends LightningElement {
    @api recordId;
    @track showConfirmation = true;
    @track message = '';
    @track messageIcon = '';
    @track messageVariant = '';

    createRecords() {
        this.showConfirmation = false; // Hide buttons while processing

        createRecords({ instId: this.recordId })
            .then(result => {
                console.log('Apex result:', result);

                switch (result) {
                    case 'SUCCESS':
                        this.message = 'Sales Order created successfully.';
                        this.messageIcon = 'utility:success';
                        this.messageVariant = 'success';
                        break;

                    case 'SO PRESENT':
                        this.message = 'Sales Order already exists.';
                        this.messageIcon = 'utility:info';
                        this.messageVariant = 'info';
                        break;

                    case 'NO ACTION':
                        this.message = 'No Sales Order was created. Please check prerequisites.';
                        this.messageIcon = 'utility:info';
                        this.messageVariant = 'info';
                        break;

                    default:
                        this.message = 'An error occurred while creating Sales Orders.';
                        this.messageIcon = 'utility:error';
                        this.messageVariant = 'error';
                        break;
                }
            })
            .catch(error => {
                console.error('Error:', error);
                this.message = 'An unexpected error occurred.';
                this.messageIcon = 'utility:error';
                this.messageVariant = 'error';
            });
    }

    closeModal() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}