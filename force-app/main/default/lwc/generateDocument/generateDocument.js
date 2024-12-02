import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import saveDoc from '@salesforce/apex/GenerateDocumentController.saveAsDocument';
import activate from '@salesforce/apex/ActivateOrderController.activateOrder';

export default class GenerateDocument extends LightningElement {
    source;
    show = false;

    @api recordId;

    connectedCallback()
    {
        
    }

    save(event)
    {
        saveDoc({qtId : this.recordId}).then(result => {
            if(result == 'SUCCESS')
            {
                const toastEvent = new ShowToastEvent({
                    title: 'Success',
                    message: 'Document Created Successfully.',
                    variant: 'success',
                    mode: 'dismissable'
                });
                this.dispatchEvent(new CloseActionScreenEvent());
            }
        }).catch(error => {
            const toastEvent = new ShowToastEvent({
                title: 'Failed',
                message: 'Error occured while creating Document.',
                variant: 'error',
                mode: 'dismissable'
            });
            this.dispatchEvent(new CloseActionScreenEvent());
        })
    }

    onYes(event)
    {
        this.show = true;
        console.log('recordId --> ' + JSON.stringify(this.recordId));
        this.source = '/apex/ContractDocumentPDF?id=' + this.recordId;
    }

}