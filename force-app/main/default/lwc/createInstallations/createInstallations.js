import { LightningElement, track, api, wire } from 'lwc';
import { getRecord} from "lightning/uiRecordApi";
import getPackageList from '@salesforce/apex/CreateInstallationsController.getPackages';
import createData from '@salesforce/apex/CreateInstallationsController.createNewInstRecord';
import checkDuplicates from '@salesforce/apex/CreateInstallationsController.checkDuplicates';
import getInstallationRecords from '@salesforce/apex/CreateInstallationsController.getInstallations';
import terminateInstallationRecords from '@salesforce/apex/CreateInstallationsController.terminateRecords';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from "lightning/pageReferenceUtils";
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
const GETRECORDFIELDS = ['Contract.ContractNumber', 'Contract.Name', 'Contract.Account.Name', 'Contract.Account.Account_ID__c', 'Contract.SBQQ__Opportunity__r.Name', 'Contract.SBQQ__Opportunity__r.Opportunity_ID__c'];

const columns = [
    { label: 'Installation Name', fieldName: 'InstUrl', type: 'url', typeAttributes: {label : { fieldName: 'InstName' }, target: '_blank'} },
    { label: 'Contract Customer', fieldName: 'CustContractUrl', type: 'url', typeAttributes: { label: {fieldName: 'CustContractName'}, target: '_blank'} },
    { label: 'Vessel', fieldName: 'VesselName' },
    { label: 'Vessel IMO', fieldName: 'VesselIMO' },
    { label: 'Installation Start Date', fieldName: 'startDate' },
    { label: 'Installation End Date', fieldName: 'endDate' }
];

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
    @track isPackageScreen = true;
    @track isQtyScreen = false;
    @track isAddPackage = false;
    @track isLoaded = false;
    @track arOptions = [
                        {label : 'Add', value : 'Add'},
                        {label : 'Terminate Installation', value : 'Terminate Installation'}
                        ];
    @track arValue;
    @track value;
    @track installationList = [];

    @track contractInfo;
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
    @track isTerminatePackage;
    @track lstOptions = [];
    lstSelected = [];
    @track termMessage = '';
    @track showInvAccFlow = false;
    @track inputVariables = [];
    instId = '' ;
    columns = columns;
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

    getPackageRecords()
    {
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
        this.installation[fieldName] = fieldValue;
    }

    onARSelected(event)
    {
        console.log('on AR Selected');
        this.isLoaded = true;
        let val = event.detail.value;
        console.log('val --> ' + val);
        if(val == 'Add')
        {
            this.getPackageRecords();
            this.isAddPackage = true;
            this.isTerminatePackage = false;
        }
        else
        {
            this.isAddPackage = false;
            this.isLoaded = false;
            this.isTerminatePackage = true;
            this.isQtyScreen = false;
            this.installationList = [];
            getInstallationRecords({
                contrId : this.recordId
            }).then(result => {
                this.installationList = result;
                for(var i = 0; i < this.installationList.length; i++)
                {
                    this.installationList[i].link = '/' + this.installationList[i].InstId;
                }
                console.log('result1 --> ' + JSON.stringify(result));
                console.log('result length --> ' + result.length);
                for(var i = 0; i < result.length; i++)
                {
                    this.lstOptions.push({
                        label : result[i].InstName,
                        value : result[i].InstId
                    });
                }
                this.disabled = false;
            }).catch(error => {
                console.log('error --> ' + JSON.stringify(error));
            });
        }
        
    }

    handleChange(event)
    {
        this.lstSelected = event.detail.value;
    }

    terminateInstallations(event)
    {
        console.log('selected recs --> ' + JSON.stringify(this.lstSelected));
        terminateInstallationRecords({
            instIdList : this.lstSelected
        }).then(result => {
            console.log('result --> ' + result);
            if(result == "SUCCESS")
            {
                this.disabled = true
                this.termMessage = 'Records Terminated Successfully';
            }
        }).catch(error => {
            console.log('error --> ' + JSON.stringify(error));
        })
    }

    onPackageSelected(event)
    {
        console.log('In pack selected');
        this.selectedPackage = event.detail.value;
        this.isQtyScreen = true;
        console.log('acc --> ' + JSON.stringify(this.accId));
        console.log('sel pack --> ' + this.selectedPackage);
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
            this.currentScreen = 'quantity';
            this.isQtyScreen = true;
            this.isPackageScreen = false;
        }
        else if(this.currentScreen == 'quantity')
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
                qty = this.packList[i].Installation_Quantity__c;
            }
        }
        console.log('quantity --> ' + this.quantity);
        console.log('qty --> ' + qty);
        console.log('total qty --> ' + totalQty);
        var totalQty = parseInt(this.quantity) + parseInt(qty);
        console.log('total qty --> ' + totalQty);
        createData({
            isTerminate : false,
            packId : this.selectedPackage,
            contrId : this.recordId,
            inst : this.installation
        }).then(result => {
            console.log('result --> ' + result);
            if(result == 'Duplicate_Error')
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
                this.instId = '/' + result.substring(result.indexOf("SUCCESS: ") + 9, result.length);
                console.log('instId --> ' + this.instId);
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
            //this.message = 'Error occured while creating the records. Please contact tech team with the these details:\n' + JSON.stringify(error);
            const event = new ShowToastEvent({
                title: 'error',
                message: 'Error occured while creating Installation.',
                variant: 'error',
                mode: 'dismissable'
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
          //  this.invAccUrl = 'lightning/action/quick/Account.New_Invoice_Account_Flow?objectApiName&context=RECORD_DETAIL&recordId=' + accId + '&backgroundContext=%2Flightning%2Fr%2FAccount%2F' + accId + '%2Fview';
        }
        else if (error) {
            console.log('error --> ' + JSON.stringify(error));
            this.error = error;
        }
    }   

}