import { LightningElement, api, track } from 'lwc';
import getFiles from '@salesforce/apex/ShowFilesController.getFiles'; 

export default class ShowFilesLWC extends LightningElement
{
    @api recordId;
    @track fileRecordList;

    connectedCallback()
    {
        console.log('in connected call back');
        getFiles({recId : this.recordId}).then(result => {
            console.log('result --> ' + JSON.stringify(result));
            this.fileRecordList = result;
        }).catch(error => {
            console.log('Error --> ' + error);
        });
    }
}