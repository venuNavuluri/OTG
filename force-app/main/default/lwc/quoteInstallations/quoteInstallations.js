import { LightningElement,wire,api,track } from 'lwc';
import { getRecord} from "lightning/uiRecordApi";
import fetchInitialConfiguration from '@salesforce/apex/QuoteInstallationController.fetchQuoteLineGroups';
import fetchProds from '@salesforce/apex/QuoteInstallationController.fetchQuoteLineGroupProducts';
import saveInstallation from '@salesforce/apex/QuoteInstallationController.saveInstallation';
import createInstallations from '@salesforce/apex/QuoteInstallationController.createInstallations';
import createRecords from '@salesforce/apex/QuoteInstallationController.createRecords';
import { NavigationMixin } from 'lightning/navigation';
const FIELDS = ['Name','SBQQ__Account__c','SBQQ__Opportunity2__c'];
const GETRECORDFIELDS = ['SBQQ__Quote__c.Name','SBQQ__Quote__c.SBQQ__Account__r.Name', 'SBQQ__Quote__c.SBQQ__Account__r.Account_ID__c','SBQQ__Quote__c.SBQQ__Opportunity2__r.Name', 'SBQQ__Quote__c.SBQQ__Opportunity2__r.Opportunity_ID__c']
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { RefreshEvent } from 'lightning/refresh';
import UploadInstallationErrorMessage from '@salesforce/label/c.Upload_Installations_Error_Message';
import {FlowAttributeChangeEvent} from 'lightning/flowSupport';
import { encodeDefaultFieldValues } from "lightning/pageReferenceUtils";

const actions = [
    // { label: 'Show details', name: 'show_details' },
    { label: 'Edit', name: 'edit' },
];
export default class QuoteInstallations extends NavigationMixin(LightningElement) {
    @api recordId
    @track quoteLineGroups=[]
    @track count = 0;
    @track isModalOpen = false;
    @track disableSave = false;
    @track remainingQty;
    @track qlgId;
    @track qgIndex;
    @track instList;
    @track openSpinner = false;
    @track message = '';
    @track showMessage = false;
    @track showRefreshMessage = false;
    @track quoteInfo
    @track accNumber;
    @track oppNumber;
    @track invAccUrl;
    @track accId = [];
    @track createInvoice = false;
    fields = FIELDS
    accName;
    oppName;
    showProductsInfo = false
    openModal = false
    @track prodsList
    currentInstallIdToEdit
    showInstallationDetail = false
    accUrl
    oppUrl
    columns = [ { label: 'Installation Id',fieldName: 'recordUrl',type: 'url',
                typeAttributes: { label: { fieldName: 'Name' }, target: '_blank',tooltip:{fieldName:"Name"} } },
                { label: 'Installation Type', fieldName: 'Installation_Type__c' },
                {label: 'Vessel/Organization Name',fieldName: 'vesselOrgLink',type: 'url',
                typeAttributes: { label: { fieldName: 'vesselOrgName' }, target: '_blank',tooltip:{fieldName:"vesselOrgName"} }},
                {label: 'Invoice Account',fieldName: 'invAcctLink',type: 'url',
                typeAttributes: { label: { fieldName: 'invAcctName' }, target: '_blank',tooltip:{fieldName:"invAcctName"} }},
                {label: 'Client',fieldName: 'clientLink',type: 'url',
                typeAttributes: { label: { fieldName: 'clientName' }, target: '_blank',tooltip:{fieldName:"clientName"} }},
                {label: 'Delivery Contact',fieldName: 'deliveryContactLink',type: 'url',
                typeAttributes: { label: { fieldName: 'deliveryContactName' }, target: '_blank',tooltip:{fieldName:"deliveryContactName"} }},
                {
                    type: 'action',
                    typeAttributes: { rowActions: actions },
                }
    ]
    /*connectedCallback(){
        this.recordId = sessionStorage.getItem("quoteRecId")
    }*/

    get acceptedFormats()
    {
        return ['.csv'];
    }

    handleUploadFinished(event)
    {
        this.openSpinner = true;
        let quoteLineGroupId = event.target.dataset.lgid;
        const uploadedFiles = event.detail.files;
        console.log('file --> ' + JSON.stringify(uploadedFiles));
        console.log('rec Id --> ' + this.recordId);
        //alert('No. of files uploaded : ' + uploadedFiles[0].contentVersionId);
        createInstallations({
            conVerId : uploadedFiles[0].contentVersionId,
            qtId : this.recordId,
            qlgId : quoteLineGroupId
        }).then(result => 
            {
                console.log('result --> ' + result);
                if(result != 'Failed')
                {
                    this.message = result;
                    this.showRefreshMessage = true;
                }
                else
                {
                    this.message = UploadInstallationErrorMessage;
                    this.showMessage = true;
                }
                this.openSpinner = false;
            }).catch(error => 
                {
                    console.log('error --> ' + JSON.stringify(error));
                    this.message = UploadInstallationErrorMessage;
                    this.showMessage = true;
                    this.openSpinner = false;
                });
    }

    refreshPage(event)
    {
        console.log('in refresh page');
        window.location.reload();
        console.log('in refresh page1');
    }

    createRecordsBulk(event)
    {
        this.isModalOpen = true;
        this.qlgId = event.target.dataset.lgid;
        this.qgIndex=event.target.dataset.qgindex;
        console.log('index --> ' + this.qgIndex);
        this.instList = this.quoteLineGroups[this.qgIndex].existingInstallations;
        console.log('instlist --> ' + this.instList);
        this.quoteLineGroups[this.qgIndex].existingInstallations = [];
        this.remainingQty = this.quoteLineGroups[this.qgIndex].remainingInstallations;
        console.log('this.quoteLineGroups[this.qgIndex].existingInstallations --> ' + this.quoteLineGroups[this.qgIndex].remainingInstallations);
    }

    handleCountChange(e)
    {
        this.count = e.detail.value;
        //let quoteLineGroupId = e.target.dataset.lgid;
        console.log('qlg id --> ' + this.remainingQty);
        if(this.remainingQty >= this.count)
        {
            this.disableSave = false;
        }
        else
        {
            this.disableSave = true;
        }
    }

    closeModalPopup()
    {
        this.isModalOpen = false;
        //this.instType = '';
    }

    closeInvoiceModal()
    {
        this.createInvoice = false;
    }

    createInstallations(event)
    {
        console.log('In create installations');
        event.preventDefault();
        let fields = event.detail.fields;
        let quoteLineGroupId = event.target.dataset.lgid;
        //let qgindexVar = event.target.dataset.qgindex;
        let quoteLineGroup = this.quoteLineGroups[this.qgIndex];
        console.log('rec Id --> ' + this.recordId);
        console.log('count --> ' + this.count);
        console.log('qlg id --> ' + this.qlgId);
        console.log('qlg index --> ' + this.qgIndex);
        //console.log('qlg --> ' + JSON.stringify(quoteLineGroup));
        this.openSpinner = true;
        createRecords({quoteId : this.recordId,
            quoteGrpId : this.qlgId,
            count : this.count,
            delvContact : fields.Delivery_Contact__c,
            invAcc : fields.Invoice_Account__c,
            client : fields.Client__c
        }).then(result => {
            console.log('result --> ' + JSON.stringify(result));
            //this.data = result;
            //this.allRecs = result;
            for(var i = 0; i < result.length; i++)
            {
                console.log('i --> ' + i);
                this.prepareRecordForTable(result[i]);
                console.log('result --> ' + JSON.stringify(result[i]));
                this.instList.push(result[i]);
                console.log('qlg --> ' + JSON.stringify(quoteLineGroup.existingInstallations));
            }
            quoteLineGroup.existingInstallations = this.instList;
            quoteLineGroup.remainingInstallations = quoteLineGroup.remainingInstallations - result.length;
            console.log('rem --> ' + quoteLineGroup.remainingInstallations);
            if(quoteLineGroup.remainingInstallations <= 0)
            {
                /*while(quoteLineGroup.newInstallations.length > 0)
                {
                    quoteLineGroup.newInstallations.pop();
                }*/
                quoteLineGroup.newInstallations = [];
            }
            this.isModalOpen = false;
            this.openSpinner = false;
        }).catch(error => {
            console.log('Error --> ' + JSON.stringify(error));
            this.openSpinner = false;
        });
    }

    fetchInstallations(){
        fetchInitialConfiguration({quoteId:this.recordId})
        .then(result => {
            if(result && result.length){
                //console.log('result --> ' + JSON.stringify(result));
                let resultArray = JSON.parse(result);
                let qlgArray = [];
                for(let listItem of resultArray){
                    //console.log('qlg --> ' + JSON.stringify(listItem));
                    let quoteLineGroup = listItem.qlg;
                    /*quoteLineGroup.installations = quoteLineGroup.Installations__r?.records
                    if(!quoteLineGroup.installations){
                        quoteLineGroup.installations = []
                    }
                    console.log('quoteLineGroup.installations --> ' + JSON.stringify(quoteLineGroup.installations));*/
                    quoteLineGroup.installationPrice = listItem.installationPrice;
                    quoteLineGroup.userPrice = listItem.userPrice;
                    quoteLineGroup.installations = [];
                    let packInstList = listItem.pack.Installations__r?.records;
                    if(!packInstList)
                    {
                        packInstList = [];
                    }
                    for(let inst of packInstList)
                    {
                        quoteLineGroup.installations.push(inst);
                    }
                    //console.log('quoteLineGroup.installations --> ' + JSON.stringify(quoteLineGroup.installations));
                    //quoteLineGroup.remainingInstallations = quoteLineGroup.Installation_Quantity__c != null?quoteLineGroup.Installation_Quantity__c-quoteLineGroup.installations.length:0
                    quoteLineGroup.remainingInstallations = quoteLineGroup.Installation_Quantity__c != null?quoteLineGroup.Installation_Quantity__c-packInstList.length:0;
                    quoteLineGroup.existingInstallations = []
                    for(let installExisting of quoteLineGroup.installations){
                        this.prepareRecordForTable(installExisting)
                        quoteLineGroup.existingInstallations.push(installExisting)
                    }
                    if(quoteLineGroup.remainingInstallations > 0 || quoteLineGroup.Installation_Quantity__c ==  null){
                        quoteLineGroup.newInstallations = this.addInstallation(1,quoteLineGroup.Id);
                    }
                    if(!quoteLineGroup.SBQQ__LineItems__r?.records){
                        continue
                    }
                    let prodList = [];
                    for(let qLine of quoteLineGroup.SBQQ__LineItems__r.records){
                        console.log(JSON.stringify(qLine))
                        let prdKey = qLine.SBQQ__Product__r.ProductCode+' : '+qLine.SBQQ__ProductName__c
                        if(!prodList.includes(prdKey)){
                            prodList.push(prdKey)
                        }
                    }
                    if(prodList.length){
                        quoteLineGroup.productsString = prodList.join(',')
                    }
                    qlgArray.push(quoteLineGroup);
                }
                this.quoteLineGroups = qlgArray;
            }
        })
        .catch(error => {

        })
    }

    prepareRecordForTable(installExisting){
        installExisting.recordUrl = '/lightning/r/Installation__c/' + installExisting.Id + '/view';
        let isVessel = installExisting.Installation_Type__c == 'Vessel'
        if (installExisting.Vessel_Name__c || installExisting.Organisation_Name__c) {
            installExisting.vesselOrgLink = '/lightning/r/' + (isVessel ? installExisting.Vessel_Name__c : installExisting.Organisation_Name__c) + '/view'
            installExisting.vesselOrgName = isVessel ? installExisting.Vessel_Name__r?.Name : installExisting.Organisation_Name__r?.Name
        }
        if (installExisting.Invoice_Account__c) {
            installExisting.invAcctLink = '/lightning/r/' + installExisting.Invoice_Account__c + '/view'
            installExisting.invAcctName = installExisting.Invoice_Account__r.Name
        }
        if (installExisting.Client__c) {
            installExisting.clientLink = '/lightning/r/' + installExisting.Client__c + '/view'
            installExisting.clientName = installExisting.Client__r?.Name
        }
        if (installExisting.Delivery_Contact__c) {
            installExisting.deliveryContactLink = '/lightning/r/' + installExisting.Delivery_Contact__c + '/view'
            installExisting.deliveryContactName = installExisting.Delivery_Contact__r.Name
        }
    }

    handleAddNew(event){
        let quoteLineGroupId = event.target.dataset.lgid;
        for(let quoteLineGroup of this.quoteLineGroups){
            if(quoteLineGroupId === quoteLineGroup.Id){
                quoteLineGroup.newInstallations.push(this.addInstallation(1,quoteLineGroupId)[0])   
            }
        }
    }
    addInstallation(installCount,quoteLineGroupId){
        let installations= []
        for(let i=0;i<installCount;i++){
            installations.push({sobjectType:'Installation__c',Quote_Line_Group__c:quoteLineGroupId})
        }
        return installations
    }

    get inputVariables() {
        return [
            {
                name: 'recordId',
                type: 'String',
                value: this.quoteInfo.fields.SBQQ__Account__r.value.id
            }
        ];
    }

    handleFlowStatusChange(event)
    {
        console.log("flow status", event.detail.status);
        if (event.detail.status === "FINISHED") {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Success",
                    message: "Invoice creation process completed Successfully",
                    variant: "success"
                })
            );
            this.createInvoice = false;
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields: GETRECORDFIELDS })
    wiredRecord({ error, data }) {
        if (data) {
            console.log(JSON.stringify(data));
            this.quoteInfo = data;
            this.accUrl = '/lightning/r/Account/'+this.quoteInfo.fields.SBQQ__Account__r.value.id+'/view';
            this.oppUrl = '/lightning/r/Opportunity/'+this.quoteInfo.fields.SBQQ__Opportunity2__r.value.id+'/view';
            var accId = this.quoteInfo.fields.SBQQ__Account__r.value.id;
            this.accId.push(accId);
            this.invAccUrl = 'lightning/action/quick/Account.New_Invoice_Account_Flow?objectApiName&context=RECORD_DETAIL&recordId=' + accId + '&backgroundContext=%2Flightning%2Fr%2FAccount%2F' + accId + '%2Fview';
            this.accNumber = this.quoteInfo.fields.SBQQ__Account__r.value.fields.Account_ID__c.value;
            this.oppNumber = this.quoteInfo.fields.SBQQ__Opportunity2__r.value.fields.Opportunity_ID__c.value;
            this.fetchInstallations();
        } else if (error) {
            console.log(error);
            this.error = error;
        }
    }   

    handleFieldChange(event){
        let indexVar = event.target.dataset.index
        let qgindexVar = event.target.dataset.qgindex
        let fieldValue = event.currentTarget.value
        let quoteLineGroupId = event.target.dataset.qgid;
        let fieldName = event.target.fieldName
        console.log(qgindexVar+' --> '+quoteLineGroupId+' --> '+indexVar+' --> '+fieldName+' --> '+fieldValue)
        let quoteLineGroup = this.quoteLineGroups[qgindexVar]
        if(fieldName === 'Installation_Type__c'){
            quoteLineGroup.newInstallations[indexVar].showVessel = fieldValue == 'Vessel'
        }
        quoteLineGroup.newInstallations[indexVar][fieldName] = fieldValue
    }

    handleNewAccCreate(){
        //window.open(this.invAccUrl);
        //this.createInvoice = true;
        /*console.log('accid --> ' + this.quoteInfo.fields.SBQQ__Account__r.value.id);
        this.dispatchEvent(new FlowAttributeChangeEvent(this.quoteInfo.fields.SBQQ__Account__r.value.id));
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: "Account",
                actionName: 'New_Invoice_Account_Flow'
            },
            state: {
                nooverride: 1,
                useRecordTypeCheck: 1,
                navigationLocation: 'RELATED_LIST',
                backgroundContext: this.invAccUrl//'/lightning/r/SBQQ__Quote__c/'+this.recordId+'/view'
            }        
        });*/
        var accId = this.accId[0];
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
        });
    }
    handleShowProducts(event){
        fetchProds({quoteGrpId:event.target.name})
        .then(result=> {
            if(result && result.length){
                this.prodsList = result
                this.showProductsInfo = true
                this.openModal = true
            }else {
                this.displayToast('No produts','No products Found','warning','dismissable')
            }
        })
        .catch(error => {
            console.log(JSON.stringify(error))
            this.displayToast('Error While Fetching Products','Error','error','dismissable')
        })
        
    }
    closeModal(){
        this.prodsList = []
        this.showProductsInfo = false
        this.openModal = false
        this.showInstallationDetail = false
        this.currentInstallIdToEdit=null
    }

    closeMessageModal()
    {
        this.showMessage = false;
    }
    
    displayToast(msg,title,variant,mode){
        const event = new ShowToastEvent({
            title: title,
            message: msg,
            variant: variant,
            mode: mode
        });
        this.dispatchEvent(event);
    }
    handleSave(event){
        let indexVar = event.target.dataset.index
        let qgindexVar = event.target.dataset.qgindex
        let quoteLineGroupId = event.target.dataset.qgid;
        console.log(qgindexVar+' --> '+quoteLineGroupId+' --> '+indexVar)
        let quoteLineGroup = this.quoteLineGroups[qgindexVar]
        if(quoteLineGroup.remainingInstallations > 0)
        {
            let installation = quoteLineGroup.newInstallations[indexVar]
            console.log('installation rec --> '+JSON.stringify(installation))
            if(installation.showVessel){
                delete installation.Organisation_Name__c
            }else {
                delete installation.Vessel_Name__c
            }
            delete installation.showVessel
            this.openSpinner = true;
            saveInstallation({sobjList : [installation]})
            .then(result => {
                installation.Id = result[0].Id
                installation.Name = result[0].Name
                this.displayToast('Installation created Succesfully','Suucess','success','dismissable')
                installation.showVessel == installation.Installation_Type__c == 'Vessel'
                quoteLineGroup.remainingInstallations = quoteLineGroup.remainingInstallations != null ? quoteLineGroup.remainingInstallations-1:0;
                quoteLineGroup.installations.push(installation)
                let newRec = {...result[0]}
                this.prepareRecordForTable(newRec)
                quoteLineGroup.existingInstallations.push(newRec)
                quoteLineGroup.newInstallations.splice(indexVar,1)
                this.openSpinner = false;
            })
            .catch(error => {
                installation.showVessel == installation.Installation_Type__c == 'Vessel'
                this.displayToast('Error Creating this Installation','Error','error','dismissable')
                this.openSpinner = false;
            })
        }
        else
        {
            this.message = "All installation records for this Quote Line Group have already been created";
            this.showMessage = true;
        }
    }
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        switch (actionName) {
            case 'edit':
                this.editRow(row);
                break;
            case 'show_details':
                window.open(row.recordUrl,'_blank')
                break;
            default:
        }
    }

    editRow(row){
        this.currentInstallIdToEdit = row.Id;
        this.showProductsInfo = false;
        this.showInstallationDetail = true;
        this.openModal = true
    }
    get getModalHeader(){
        return this.showProductsInfo ? 'Products' : 'Edit Installation'
    }
    
    get getModalSize(){
        return this.showInstallationDetail ? 'slds-modal slds-fade-in-open slds-modal_medium':'slds-modal slds-fade-in-open'
    }
}