import { LightningElement, api, track } from 'lwc';
import createRecords from '@salesforce/apex/CreateBulkInstallationRecordsController.createRecords';
import updateInstallationRecords from '@salesforce/apex/CreateBulkInstallationRecordsController.updateInstallationRecords';
import validateCount from '@salesforce/apex/CreateBulkInstallationRecordsController.validateCount';
import getExistingInstallationRecords from '@salesforce/apex/CreateBulkInstallationRecordsController.getExistingInstallationRecords';

const columns = [
    { label: 'Installation Id', fieldName: 'InstName' },
    { label: 'Customer Name', fieldName: 'CustomerName', type: 'String' },
    { label: 'Installation Type', fieldName: 'InstallationType', type: 'String', editable: true },
    { label: 'Vessel/Organisation Name', fieldName: 'VesOrgName', type: 'String', editable: true },
    { label: 'Delivery Contact', fieldName: 'DelvContact', type: 'String', editable: true },
    { label: 'Client Name', fieldName: 'ClientName', type: 'String', editable: true },
    { label: 'Invoice Account Name', fieldName: 'InvAccName', type: 'String', editable: true }
];

export default class CreateBulkInstallationRecords extends LightningElement {
    @api recordId;
    @track instType;
    @track count = 0;
    @track data = [];
    @track allRecs = [];
    @track columns = columns;
    @track isModalOpen = false;
    @track vesType = false;
    @track orgType = false;
    @track disableSave;
    @track remainingQty;
    @track delvCont;
    @track invAccName;
    @track clientName;
    @api parentAccountSelectedRecord;
    
    handleValueSelectedOnAccount(event) {
        this.parentAccountSelectedRecord = event.detail;
        console.log('selected --> ' + JSON.stringify(this.parentAccountSelectedRecord));
        getExistingInstallationRecords({quoteGrpId : this.parentAccountSelectedRecord.id}).then(result => {
            console.log('result --> ' + JSON.stringify(result));
            if(result != null)
            {
                this.data = result;
                this.allRecs = result;
                this.count = 0;
                this.disableSave = false;
            }
        }).catch(error => {
            console.log('error --> ' + JSON.stringify(error));
        })
    }

    onInstallationTypeChange(event)
    {
        console.log('evt --> ' + JSON.stringify(event.detail.value));
        this.instType = event.detail.value;
        if(this.instType == 'Vessel')
        {
            this.vesType = true;
            this.orgType = false;
        }
        else if(this.instType == 'Organisation')
        {
            this.orgType = true;
            this.vesType = false;
        }
    }

    updateRecords()
    {
        this.isModalOpen = true;
        this.instType = null;
    }

    closeModal()
    {
        this.isModalOpen = false;
        this.instType = '';
    }

    handleUpdateInstallation(event)
    {
        event.preventDefault();
        var selectedRecords =  this.template.querySelector("lightning-datatable").getSelectedRows();
        if(selectedRecords.length > 0)
        {
            console.log('selectedRecords are ', JSON.stringify(selectedRecords));
            let fields = event.detail.fields;
            this.data = null;
            updateInstallationRecords({allRecsStr : JSON.stringify(this.allRecs),
                                        instWrapListStr : JSON.stringify(selectedRecords),
                                        instType : fields.Installation_Type__c,
                                        vesselType: fields.Vessel_Name__c,
                                        orgType : fields.Organisation_Name__c,
                                        delvCont : fields.Delivery_Contact__c,
                                        client : fields.Client__c,
                                        invAcc : fields.Invoice_Account__c
                                    }).then(result => {
                                        console.log('result --> ' + JSON.stringify(result));
                                        this.allRecs = result;
                                        console.log('data1 --> ' + JSON.stringify(this.data));
                                        this.data = result;
                                        console.log('data2 --> ' + JSON.stringify(this.data));
                                        this.isModalOpen = false;
                                    }).catch(error => {
                                        console.log('Error --> ' + error);
                                        this.isModalOpen = false;
                                    });
        }
    }

    connectedCallback() {
        //const data = generateData({ amountOfRecords: 100 });
        //this.data = data;
    }

    handleSubmit(event)
    {
        //event.preventDefault(); // do this so that you can modify the form values
        let fields = event.detail.fields;
        console.log('rec Id --> ' + this.recordId);
        console.log('count --> ' + this.count);
        /*, vessel : fields.Vessel_Name__c,
            org : fields.Organisation_Name__c*/
        createRecords({quoteId : this.recordId,
            quoteGrpId : this.parentAccountSelectedRecord.id,
            count : this.count}).then(result => {
            console.log('result --> ' + JSON.stringify(result));
            this.data = result;
            this.allRecs = result;
        }).catch(error => {
            console.log('Error --> ' + error);
        });
        //this.template.querySelector('lightning-record-edit-form').submit(fields); // need to submit form again because we have fired preventDefault before
        //alert('handleSubmit()--->');
    }

    handleCountChange(e)
    {
        this.count = e.detail.value;
        validateCount({quoteGrpId : this.parentAccountSelectedRecord.id, count : this.count}).then(result => {
            console.log('res --> ' + JSON.stringify(result));
            if(result >= this.count)
            {
                this.disableSave = false;
                this.remainingQty = result;
            }
            else
            {
                this.disableSave = true;
                this.remainingQty = result;
            }
        }).catch(error => {
            console.log('error --> ' + error);
        })
    }
}