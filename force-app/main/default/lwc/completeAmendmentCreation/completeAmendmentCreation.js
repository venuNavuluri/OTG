import { LightningElement, track } from 'lwc';
import createQuoteLineGroups from '@salesforce/apex/CompleteAmendmentCreationController.createQuoteLineGroups'

export default class CompleteAmendmentCreation extends LightningElement 
{
    @track isLoading = false;
    @track isError = false;
    connectedCallback()
    {
        this.isLoading = true;
        createQuoteLineGroups({quoteId : recordId}).then(result => {
            if(result == 'SUCCESS')
            {
                this.isLoading = false;
            }
            else
            {
                console.log('msg --> ' + result);
                this.isError = true;
            }
        }).catch(error => {
            console.log('error --> ' + error);
            this.isError = true;
        });
    }
}