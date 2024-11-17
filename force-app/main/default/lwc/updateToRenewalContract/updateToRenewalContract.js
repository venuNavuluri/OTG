import { LightningElement, api } from 'lwc';
import { updateRecord } from 'lightning/uiRecordApi';

export default class UpdateToRenewalContract extends LightningElement {
    @api recordId;

    renderedCallback()
    {
        updateRecord({fields : {
            Id : this.recordId,
            SBQQ__RenewalForecast__c : true,
            SBQQ__RenewalQuoted__c : true
        }}).then(result => {
            console.log('result --> ' + JSON.stringify(result));
        }).catch(error => {
            console.log('error --> ' + JSON.stringify(error));
        })
    }
}