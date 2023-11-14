import { LightningElement, api, track, wire } from 'lwc';
import { getRecord} from "lightning/uiRecordApi";
const FIELDS = ['Installation__c.Name','Installation__c.Quote__c','Installation__c.Package__c'];
import { CloseActionScreenEvent } from 'lightning/actions';
import getPackageInfo from '@salesforce/apex/UpdatePackageController.getPackageData';
import fetchPackages from '@salesforce/apex/UpdatePackageController.fetchPackages';
import saveInstallationRecord from '@salesforce/apex/UpdatePackageController.saveInstallation';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
const columns = [
    { label: 'Installation Name', fieldName: 'Name' },
    { label: 'Vessel IMO', fieldName: 'Vessel_IMO__c'}
];

export default class UpdatePackage extends LightningElement 
{
    @api recordId;
    @track packageId;
    @track quoteId;
    @track objectApiName = 'Installation__c';
    @track packageApiName = 'Package__c';
    @track packageValue;
    @track packageOptions = [];
    @track selectedPackage;
    @track installations = [];
    @track showInstallations = false;
    columns = columns;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data })
    {
        if (data)
        {
            console.log(JSON.stringify(data));
            this.packageId = data.fields.Package__c.value;
            this.quoteId = data.fields.Quote__c.value;
            this.fetchAvailablePacks();
        }
        else if (error)
        {
            console.log(error);
            this.error = error;
        }
    }

    updatePackage(event)
    {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    fetchAvailablePacks()
    {
        console.log('In fetch - ' + this.quoteId);
        fetchPackages({
            qtId : this.quoteId
        }).then(result => {
            console.log('result --> ' + JSON.stringify(result));
            if(result && result.length)
            {
                //let resultArray = JSON.parse(result);
                for(let rec of result)
                {
                    this.packageOptions.push({
                        label : rec.Name,
                        value : rec.Id
                    });
                }
            }
            console.log('packageOptions --> ' + this.packageOptions);
        }).catch(error => {
            console.log('error --> ' + error);
        });
    }

    savePackageInfo(event)
    {
        var selectedRecords =  this.template.querySelector("lightning-datatable").getSelectedRows();
        console.log('selectedRecords --> ' + JSON.stringify(selectedRecords));
        if(selectedRecords.length == 1){
            console.log('selectedRecords are ', selectedRecords);
            /*let ids = '';
            selectedRecords.forEach(currentItem => {
                ids = ids + ',' + currentItem.Id;
            });
            this.selectedIds = ids.replace(/^,/, '');*/
            saveInstallationRecord({
                packId: this.selectedPackage,
                instId: this.recordId,
                swapInstId: selectedRecords[0].Id
            }).then(result => {
                const evt = new ShowToastEvent({
                    title: 'Saved Successfully',
                    message: 'Package updated Successfully',
                    variant: 'success',
                });
                this.dispatchEvent(evt);
                this.dispatchEvent(new CloseActionScreenEvent());
            }).catch(error => {
                console.log('error --> ' + error);
            });
        }
        else if(selectedRecords.length > 1)
        {
            const evt = new ShowToastEvent({
                title: 'More records selected',
                message: 'You have to select only one record',
                variant: 'error',
            });
            this.dispatchEvent(evt);
        }
        else
        {
            const evt = new ShowToastEvent({
                title: 'No records selected',
                message: 'You have to select atleast one record',
                variant: 'error',
            });
            this.dispatchEvent(evt);
        }
    }

    handleSelected(event)
    {
        console.log("In handle selected" + this.selectedPackage + event.target.value);
        this.selectedPackage = event.target.value;
        getPackageInfo({
            packId : this.selectedPackage
        }).then(result => {
            console.log('result --> ' + JSON.stringify(result));
            console.log('inst --> ' + JSON.stringify(result[0].Installations__r));
            console.log('result --> ' + result[0].Installations__r.length + ' ' + result[0].Installation_Quantity__c);
            if(result[0].Installation_Quantity__c <= result[0].Installations__r.length)
            {
                this.installations = result[0].Installations__r;
                this.showInstallations = true;
                console.log('inst --> ' + this.installations);
            }
            else
            {
                this.installations = [];
                this.showInstallations = false;
                console.log('inst --> ' + this.installations);
            }
        }).catch(error => {
            console.log('error --> ' + error);
        });
    }
}