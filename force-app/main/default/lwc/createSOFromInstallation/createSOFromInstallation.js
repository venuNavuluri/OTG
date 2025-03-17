import { LightningElement, api, track, wire } from 'lwc';
import createRecords from '@salesforce/apex/CreateSalesOrders.createSORecordsInst';
import {CloseActionScreenEvent} from 'lightning/actions';
import { getRecord } from 'lightning/uiRecordApi';
import SALES_ORDERS_CREATED from '@salesforce/schema/Contract.Sales_Orders_Created__c';

export default class CreateSOFromInstallation extends LightningElement {
    @api recordId;
    @track showConfirmation = true;
    @track message = '';
    @track soCreated;
    
    @wire(getRecord, { recordId : "$recordId", fields : [SALES_ORDERS_CREATED]}) ContractRecord({error, data}) {
        if(data)
        {
            console.log('data --> ' + JSON.stringify(data));
            this.soCreated = data.fields.Sales_Orders_Created__c.value;
            if(this.soCreated)
            {
                this.showConfirmation = false;
                this.message = 'Sales Orders were created already.';
            }
        }
        else
        {
            console.log('error --> ' + JSON.stringify(error));
        }
    };

    createRecords()
    {
        createRecords({
            instId : this.recordId
        }).then(result => {
            console.log('result --> ' + result);
            if(result == 'SUCCESS')
            {
                this.message = 'Sales Order created Successfully.';
                this.showConfirmation = false;
            }
            else if(result == 'SO PRESENT')
            {
                this.message = 'Sales order already created';
                this.showConfirmation = false;
            }
            else
            {
                this.message = 'Error occured while creating Sales Orders.';
                this.showConfirmation = false;
            }
        }).catch(error => {
            console.log('error --> ' + error);
            this.message = 'Error occured while creating Sales Orders.';
            this.showConfirmation = false;
        })
    }
    
    closeModal(event)
    {
        console.log('in closemodal');
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}