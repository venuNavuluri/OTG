// createLeadFromURL.js
import { LightningElement, api } from 'lwc';
import { createRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CreateLeadFromURL extends LightningElement {
    @api emailAddress;
    @api campaignId;

    connectedCallback() {
        this.createLead();
    }

    createLead() {
        const fields = {
            Email: this.emailAddress,
            CampaignID: this.campaignId
        };
        const recordInput = { apiName: 'Lead', fields };

        createRecord(recordInput)
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Lead created successfully',
                        variant: 'success'
                    })
                );
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error creating lead',
                        message: error.body.message,
                        variant: 'error'
                    })
                );
            });
    }
}
