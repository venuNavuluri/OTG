import { LightningElement, track, api, wire } from 'lwc';
import { getRecord} from "lightning/uiRecordApi";
import getPackageList from '@salesforce/apex/CreateInstallationsController.getPackages';
import createData from '@salesforce/apex/CreateInstallationsController.createNewInstRecord';
import validateOpenItems from '@salesforce/apex/CreateInstallationsController.validateOpenQuotesOrders';
import checkDuplicates from '@salesforce/apex/CreateInstallationsController.checkDuplicates';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from "lightning/pageReferenceUtils";
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
const GETRECORDFIELDS = ['Contract.ContractNumber', 'Contract.Name', 'Contract.Account.Name', 'Contract.Account.Account_ID__c', 'Contract.SBQQ__Opportunity__r.Name', 'Contract.SBQQ__Opportunity__r.Opportunity_ID__c'];

export default class CreateInstallations extends NavigationMixin(LightningElement)
{
    @api recordId;
    @track packList;
    @track options=[];
    @track selectedPackage;
    @track isModalOpen = true;
    @track currentScreen = 'package';
    @track quantity;
    @track message = '';
    @track showMessage = false;
    @track showErrorMessage = false;
    @track disabled = true;
    @track isPackageScreen = false;
    @track isQtyScreen = false;
    @track isLoaded = false;
    @track value;
    @track contractInfo;
    @track isPackageSelected = false;
    @track accNumber;
    @track oppNumber;
    @track invAccUrl;
    @track accId = [];
    @track accUrl;
    @track oppUrl;
    @track accName;
    @track oppName;
    @track installation = {showVessel : true};
    filter;
    @track isPackageSelected = false;
    @track showPackagePicker = false;
    @track warnings;

    get disableConfirm() {
        return !this.isPackageSelected;
    }

    get selectedPackageName() {
        if (!this.selectedPackage || !this.packList) {
            return '';
        }
        const match = this.packList.find(pack => pack.Id === this.selectedPackage);
        return match ? match.Name : '';
    }

    formatWarningMessages(warnings) {
        if (!warnings || !Array.isArray(warnings)) {
            return null;
        }

        return warnings.map((warning) => {
            if (typeof warning !== 'string' || warning.includes('<a ')) {
                return warning;
            }

            const primaryLinkPattern = /(Quote|Order)\s+([^\(]+?)\s+\(\/([a-zA-Z0-9]{15,18})\)/g;
            const withPrimaryLink = warning.replace(primaryLinkPattern, (_match, label, name, recordId) => {
                const href = `/${recordId}`;
                return `${label} <a href="${href}" target="_blank">${name.trim()}</a>`;
            });

            return withPrimaryLink.replace(/\(\/([a-zA-Z0-9]{15,18})\)/g, (_match, recordId) => {
                const href = `/${recordId}`;
                return `<a href="${href}" target="_blank">${href}</a>`;
            });
        });
    }

    @track showInvAccFlow = false;
    @track inputVariables = [];
    instId = '' ;
    matchingInfo = {
        primaryField: { fieldPath: 'Name' },
        additionalFields: [{ fieldPath: 'Account_ID__c' }],
    };

    viewRecord(event)
    {
        console.log('instId view rec --> ' + this.instId);
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                "recordId": this.instId,
                "objectApiName": "Account",
                "actionName": "view"
            }
        });
        console.log('end view record');
    }

    handleNewAccCreate()
    {
        console.log('handleNewAccCreate');
        /*var accId = this.accId[0];
        const defaultValues = encodeDefaultFieldValues({
            ParentId : accId,
            B2B_Account__c : accId
        });
      
        console.log('defaultValues --> ' + JSON.stringify(defaultValues));
      
        this[NavigationMixin.Navigate]({
            type: "standard__objectPage",
            attributes: {
                objectApiName: "Account",
                actionName: "new",
            },
            state: {
                nooverride: '1',
                defaultFieldValues: defaultValues,
                recordTypeId : '0124K000000MkfSQAS'
            }
        });*/
        console.log('end');
        this.showInvAccFlow = true;
        this.inputVariables = [
            {
                name: 'recordId',
                type: 'String',
                value: this.contractInfo.fields.Account.value.id
            }
        ]
    }

    hideModalBox(event)
    {
        this.showInvAccFlow=false;
    }

    handleStatusChange()
    {}

    getPackageRecords() {
        this.isLoaded = true;
        getPackageList({
            contrId : this.recordId
        }).then(result => {
            this.packList = result;
            console.log('packList1--> ' + JSON.stringify(this.packList));
            this.options = [];
            for(var i = 0; i < this.packList.length; i++)
            {
                console.log('packName --> ' + this.packList[i].Name);
                console.log('packId --> ' + this.packList[i].Id);
                this.options.push(
                    { label: this.packList[i].Name, value: this.packList[i].Id }
                );
            }
            console.log('packogs --> ' + JSON.stringify(this.packList));
            console.log('packList--> ' + JSON.stringify(this.options));
            this.isLoaded = false;
        }).catch(error => {
            console.log('error --> ' + error);
            this.isLoaded = false;
        })
    }

    handleFieldChange(event)
    {
        let fieldValue = event.currentTarget.value
        let fieldName = event.target.fieldName
        console.log(fieldName+' field--> '+fieldValue);
        console.log('event detail --> ' + event.detail);
        if(fieldName == 'Installation_Type__c')
        {
            if(fieldValue == 'Vessel')
            {
                this.installation.showVessel = true;
            }
            else
            {
                this.installation.showVessel = false;
            }
        }
        if (fieldName == 'Vessel_Name__c' || fieldName == 'Organisation_Name__c') {
            checkDuplicates({
                contrId : this.recordId,
                vesId : fieldValue,
                orgId : null
            }).then(result => {
                console.log('result --> ' + result);
                if (result == true)
                {
                    fieldValue = "";
                    console.log('in if 1');
                    //event.target.closest("lightning-input-field").value = "";
                    this.installation.dupId = true;   
                    this.installation.disButton = true;
                    console.log('end if 1');
                }
                else
                {
                    this.installation.dupId = false; 
                    this.installations.disButton = false;
                }
            }).catch(error => {
                console.log('error --> ' + JSON.stringify(error));
            });
        }
        if(fieldName == null || fieldName === undefined)
        {
            console.log('in if --> ' + fieldName);
            fieldName = event.target.dataset.fieldname;
            fieldValue = event.detail.recordId;
            console.log('in if --> ' + fieldName);
            if(fieldName == 'Invoice_Account__c' && fieldValue != null)
            {
                this.disabled = false;
            }
        }
        if (fieldName === 'Installation_Start_date__c' && fieldValue && typeof fieldValue === 'object' && fieldValue.hasOwnProperty('value')) {
            fieldValue = fieldValue.value;
        }
        this.installation[fieldName] = fieldValue;
    }

    startAddFlow() {
        this.isLoaded = true;
        this.warnings = null;
        this.showPackagePicker = false;
        this.isPackageScreen = false;

        validateOpenItems({ contractId: this.recordId })
            .then(result => {
                this.isLoaded = false;
                if (result && result.length > 0) {
                    this.warnings = this.formatWarningMessages(result);
                } else {
                    this.isPackageScreen = true;
                    this.showPackagePicker = true;
                    this.currentScreen = 'package';
                    this.isQtyScreen = false;
                    if (!this.packList || this.packList.length === 0) {
                        this.getPackageRecords();
                    }
                }
            })
            .catch(error => {
                this.isLoaded = false;
                console.error('validateOpenItems error', JSON.stringify(error));
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Unable to validate open Quotes/Orders. Please try again later.',
                        variant: 'error'
                    })
                );
            });
    }

    handlePackageSelection(event) {
        console.log('Package selected');
        this.selectedPackage = event.detail.value;
        this.value = this.selectedPackage;
        this.isPackageSelected = Boolean(this.selectedPackage);
    }

    getErrorMessage(error) {
        if (!error) {
            return 'An unexpected error occurred.';
        }

        if (Array.isArray(error.body)) {
            return error.body.map(item => item.message).join(', ');
        }

        if (error.body && error.body.message) {
            return error.body.message;
        }

        if (error.message) {
            return error.message;
        }

        return 'An unexpected error occurred.';
    }

    confirmPackage() {
        if (!this.selectedPackage) {
            return;
        }
        this.isQtyScreen = true;
        this.isPackageScreen = false;
        this.showPackagePicker = false;
        this.currentScreen = 'quantity';
        console.log('Selected package -> ' + this.selectedPackage);
        this.filter = {
            criteria: [
                { fieldPath: 'B2B_Account__c', operator: 'eq', value: this.accId[0] },
                { fieldPath: 'RecordTypeId', operator: 'eq', value: '0124K000000MkfSQAS'},
                { fieldPath: 'RecordTypeId', operator: 'eq', value: '0124K000000DmQOQA0'}
            ],
            filterLogic: '1 AND (2 OR 3)'
        };
    }

    onQuantityChanged(event)
    {
        console.log('val --> ' + event.detail.value);
        this.quantity = event.detail.value;
        console.log('qty --> ' + this.quantity);
    }
    closeModalPopup(event)
    {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
    onNext(event)
    {
        if(this.currentScreen == 'package')
        {
            if (!this.selectedPackage) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Warning',
                    message: 'Please select a package before continuing.',
                    variant: 'warning'
                }));
                return;
            }
            this.confirmPackage();
        }
        if(this.currentScreen == 'quantity')
        {
            for(let pack in this.packList)
            {
                if(pack.Id == this.selectedPackage && this.quantity > pack.Installation_Quantity__c)
                {
                    this.message = 'Please select a quantity less than ' + pack.Installation_Quantity__c;
                    this.showMessage = true;
                    this.disabled = true;
                }
            }
        }
    }

    onSave(event)
    {
        this.isLoaded = true;
        var qty = 0;
        for(var i = 0; i < this.packList.length; i++)
        {
            if(this.selectedPackage == this.packList[i].Id)
            {
                console.log('packName --> ' + this.packList[i].Installation_Quantity__c);
                qty = this.packList[i].Installation_Quantity__c || 0;
            }
        }
        console.log('quantity --> ' + this.quantity);
        console.log('qty --> ' + qty);
        const totalQty = (parseInt(this.quantity, 10) || 0) + parseInt(qty, 10);
        console.log('total qty --> ' + totalQty);
        createData({
            isTerminate : false,
            packId : this.selectedPackage,
            contrId : this.recordId,
            inst : this.installation,
            startDate : this.installation.Installation_Start_date__c // Pass the captured start date
        }).then(result => {
            console.log('result --> ' + result);
            if(result === 'Duplicate_Error')
            {
                this.isLoaded = false;
                const event = new ShowToastEvent({
                    title: 'error',
                    message: 'Duplicate vessel found, please change the vessel and try again.',
                    variant: 'error',
                    mode: 'dismissable'
                });
                this.dispatchEvent(event);
            }
            else
            {
                this.disabled = true;
                this.message = 'Records created successfully';
                this.showMessage = true;
                this.showErrorMessage = false;
                this.isLoaded = false;
                const successPrefix = 'SUCCESS: ';
                const prefixIndex = result ? result.indexOf(successPrefix) : -1;
                if (prefixIndex !== -1) {
                    this.instId = '/' + result.substring(prefixIndex + successPrefix.length);
                } else {
                    this.instId = null;
                }
                const event = new ShowToastEvent({
                    title: 'Success',
                    message: 'Installation Created Successfully. {0} to navigate to the record',
                    messageData: [{
                        url: this.instId,
                        label: 'Click here'
                    }],
                    variant: 'success',
                    mode: 'dismissable'
                });
                this.dispatchEvent(event);
            }
        }).catch(error => {
            console.log('error --> ' + JSON.stringify(error));
            this.isLoaded = false;
            const errorMessage = this.getErrorMessage(error);
            this.message = errorMessage;
            this.showErrorMessage = true;
            this.showMessage = false;
            const event = new ShowToastEvent({
                title: 'error',
                message: errorMessage,
                variant: 'error',
                mode: 'sticky'
            });
            this.dispatchEvent(event);
            //this.showErrorMessage = true;
            //this.showMessage = false;
        })
    }


     @wire(getRecord, { recordId: '$recordId', fields: GETRECORDFIELDS })
    wiredRecord({ error, data }) {
        if (data) {
            console.log(JSON.stringify(data));
            this.contractInfo = data;
            this.accUrl = '/lightning/r/Account/'+this.contractInfo.fields.Account.value.id+'/view';
            if(this.contractInfo.fields.SBQQ__Opportunity__r != null && this.contractInfo.fields.SBQQ__Opportunity__r.value != null)
            {
                this.oppUrl = '/lightning/r/Opportunity/'+this.contractInfo.fields.SBQQ__Opportunity__r.value.id+'/view';
                this.oppNumber = this.contractInfo.fields.SBQQ__Opportunity__r.value.fields.Opportunity_ID__c.value;
            }
            var accId = this.contractInfo.fields.Account.value.id;
            this.accId.push(accId);
            this.accNumber = this.contractInfo.fields.Account.value.fields.Account_ID__c.value;
            if (!this.packList || this.packList.length === 0) {
                this.getPackageRecords();
            }
          //  this.invAccUrl = 'lightning/action/quick/Account.New_Invoice_Account_Flow?objectApiName&context=RECORD_DETAIL&recordId=' + accId + '&backgroundContext=%2Flightning%2Fr%2FAccount%2F' + accId + '%2Fview';
        }
        else if (error) {
            console.log('error --> ' + JSON.stringify(error));
            this.error = error;
        }
    }   

}