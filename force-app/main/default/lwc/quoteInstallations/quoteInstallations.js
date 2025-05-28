import { LightningElement,wire,api,track } from 'lwc';
import { getRecord} from "lightning/uiRecordApi";
import fetchInitialConfiguration from '@salesforce/apex/QuoteInstallationController.fetchQuoteLineGroups';
import fetchProds from '@salesforce/apex/QuoteInstallationController.fetchQuoteLineGroupProducts';
import saveInstallation from '@salesforce/apex/QuoteInstallationController.saveInstallation';
import createInstallations from '@salesforce/apex/QuoteInstallationController.createInstallations';
import createRecords from '@salesforce/apex/QuoteInstallationController.createRecords';
import getPackageInfo from '@salesforce/apex/UpdatePackageController.getPackageData';
import fetchPackages from '@salesforce/apex/UpdatePackageController.fetchPackages';
import saveInstallationRecord from '@salesforce/apex/UpdatePackageController.saveInstallation';
import { NavigationMixin } from 'lightning/navigation';
const FIELDS = ['Name','SBQQ__Account__c','SBQQ__Opportunity2__c'];
const GETRECORDFIELDS = ['SBQQ__Quote__c.Name','SBQQ__Quote__c.SBQQ__Account__r.Name', 'SBQQ__Quote__c.SBQQ__Account__r.Account_ID__c','SBQQ__Quote__c.SBQQ__Opportunity2__r.Name', 'SBQQ__Quote__c.SBQQ__Opportunity2__r.Opportunity_ID__c']
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
//import { RefreshEvent } from 'lightning/refresh';
import UploadInstallationErrorMessage from '@salesforce/label/c.Upload_Installations_Error_Message';
//import {FlowAttributeChangeEvent} from 'lightning/flowSupport';
import { encodeDefaultFieldValues } from "lightning/pageReferenceUtils";

const actions = [
    // { label: 'Show details', name: 'show_details' },
    { label: 'Edit', name: 'edit' },
    { label: 'Change Package', name: 'Change_Package' }
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
    @track packageOptions = [];
    @track showChangePackage = false;
    @track selectedPackage;
    @track showInstallations = false;
    @track installations = [];
    @track changeInstId;
    @track selectedRows = [];
    @track renderChangePackage = false;
    @track showInvoiceError = false;
    invoiceAccountValue = '';
    instColumns = [
        { label: 'Installation Name', fieldName: 'Name' },
        { label: 'Vessel IMO', fieldName: 'Vessel_IMO__c'}
    ];
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
                typeAttributes: { label: { fieldName: 'Name' }, target: '_blank',tooltip:{fieldName:"Name"} },
                cellAttributes: { class: { fieldName: 'rowStyle' }, } },
                { label: 'Installation Type', fieldName: 'Installation_Type__c', cellAttributes: { class: { fieldName: 'rowStyle' }, } },
                {label: 'Vessel/Organization Name',fieldName: 'vesselOrgLink',type: 'url',
                typeAttributes: { label: { fieldName: 'vesselOrgName' }, target: '_blank',tooltip:{fieldName:"vesselOrgName"} },
                cellAttributes: { class: { fieldName: 'rowStyle' }, } },
                {label: 'Invoice Account',fieldName: 'invAcctLink',type: 'url',
                typeAttributes: { label: { fieldName: 'invAcctName' }, target: '_blank',tooltip:{fieldName:"invAcctName"} },
                cellAttributes: { class: { fieldName: 'rowStyle' } } },
                {label: 'Client',fieldName: 'clientLink',type: 'url',
                typeAttributes: { label: { fieldName: 'clientName' }, target: '_blank',tooltip:{fieldName:"clientName"} },
                cellAttributes: { class: { fieldName: 'rowStyle' }, } },
                {label: 'Delivery Contact',fieldName: 'deliveryContactLink',type: 'url',
                typeAttributes: { label: { fieldName: 'deliveryContactName' }, target: '_blank',tooltip:{fieldName:"deliveryContactName"} },
                cellAttributes: { class: { fieldName: 'rowStyle' }, }},
                {
                    type: 'action',
                    typeAttributes: { rowActions: actions },
                }
    ]

    filter;

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
        let qgindexVar = event.target.dataset.qgindex;
        let quoteLineGroup = this.quoteLineGroups[qgindexVar]
        const uploadedFiles = event.detail.files;
        console.log('file --> ' + JSON.stringify(uploadedFiles));
        console.log('rec Id --> ' + this.recordId);
        //alert('No. of files uploaded : ' + uploadedFiles[0].contentVersionId);
        createInstallations({
            conVerId : uploadedFiles[0].contentVersionId,
            qtId : this.recordId,
            qlgId : quoteLineGroupId,
            instPrice : quoteLineGroup.installationPrice
        }).then(result => 
            {
                console.log('result --> ' + result);
                if(result != 'Failed')
                {
                    /*this.message = result;
                    this.showRefreshMessage = true;*/
                    const event = new ShowToastEvent({
                        title: 'Success',
                        message: 'Installations Created Successfully.',
                        variant: 'success',
                        mode: 'dismissable'
                    });
                }
                else
                {
                    /*this.message = UploadInstallationErrorMessage;
                    this.showMessage = true;*/
                    const event = new ShowToastEvent({
                        title: 'Failed',
                        message: 'Error occured while creating installations.',
                        variant: 'error',
                        mode: 'dismissable'
                    });
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
        console.log('recId --> ' + this.recordId);
        console.log('qlg --> ' + JSON.stringify(this.quoteLineGroups));
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
                        console.log('instExisting --> ' + JSON.stringify(installExisting));
                        quoteLineGroup.existingInstallations.push(installExisting)
                    }
                    if(quoteLineGroup.remainingInstallations > 0 || quoteLineGroup.Installation_Quantity__c ==  null){
                        quoteLineGroup.newInstallations = this.addInstallation(1,quoteLineGroup.Id);
                    }
                    if(quoteLineGroup.SBQQ__LineItems__r?.records)
                    {
                        let prodList = [];
                        for(let qLine of quoteLineGroup.SBQQ__LineItems__r.records){
                            console.log(JSON.stringify(qLine))
                            let prdKey = qLine.SBQQ__Product__r.ProductCode+' : '+qLine.SBQQ__ProductName__c
                            if(!prodList.includes(prdKey)){
                                prodList.push(prdKey)
                            }
                        }
                        console.log('length --> ' + prodList.length);
                        console.log('prdList --> ' + JSON.stringify(prodList));
                        if(prodList.length){
                            console.log('in if304');
                            quoteLineGroup.productsString = prodList.join(',');
                            console.log('in if 306');
                        }
                        else
                        {
                            console.log('in else 310');
                            quoteLineGroup.productsString = '';
                            console.log('in else 312');
                        }
                    }
                    console.log('qlgArray1 --> ' + JSON.stringify(qlgArray));
                    qlgArray.push(quoteLineGroup);
                    console.log('qlgArray2 --> ' + JSON.stringify(qlgArray));
                }
                console.log('qlgs01 --> ' + this.quoteLineGroups);
                console.log('qlgs1 --> ' + JSON.stringify(this.quoteLineGroups));
                this.quoteLineGroups = qlgArray;
                console.log('qlgs2 --> ' + JSON.stringify(this.quoteLineGroups));
            }
            console.log('qlg --> ' + JSON.stringify(this.quoteLineGroups));
            console.log('arr length --> ' + this.quoteLineGroups.length);
            if(this.quoteLineGroups.length > 1)
            {
                console.log('1');
                this.renderChangePackage = true;
                console.log("2");
            }
        })
        .catch(error => {
            console.log('error --> ' + JSON.stringify(error));
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
        console.log('inst qt Id --> ' + installExisting.Quote__c)
        console.log('exists inst id --> ' + this.recordId);
        if(installExisting.Quote__c == this.recordId)
        {
            installExisting.rowStyle = 'highLight';
        }

        if(installExisting.Quote__c == undefined)
        {
            installExisting.Quote__r = {Name : ''};
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
            installations.push({sobjectType:'Installation__c',Quote_Line_Group__c:quoteLineGroupId,disButton:false})
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
            this.filter = {
                criteria: [
                    { fieldPath: 'B2B_Account__c', operator: 'eq', value: this.quoteInfo.fields.SBQQ__Account__r.value.id },
                    { fieldPath: 'RecordTypeId', operator: 'eq', value: '0124K000000MkfSQAS'},
                    { fieldPath: 'RecordTypeId', operator: 'eq', value: '0124K000000DmQOQA0'}
                ],
                filterLogic: '1 AND (2 OR 3)'
            };
        } else if (error) {
            console.log(error);
            this.error = error;
        }
    }   
    checkForDuplicate(pkgIndx, installIndx, pkgId, exVesselId, fieldName, isVessel) {
        //var existPackage = this.quoteLineGroups[pkgIndx];
        var matchVessel = false;
        //if (existPackage) {
        this.quoteLineGroups.forEach(existPackage => {
            var existInstall = existPackage.existingInstallations;
            existInstall.forEach(element => {
                console.log('element --> ' + JSON.stringify(element) + ' ' + element.Vessel_Name__c);
                if ((isVessel && element.Vessel_Name__c == exVesselId) || (!isVessel && element.Organisation_Name__c == exVesselId) && exVesselId != "") {
                    //alert('Duplicate Vessel/Org ID from existing Installations');
                    matchVessel = true;
                }
            });
        });
        //}
        return matchVessel;
    }

    validateInvoiceAccount(event) {
        let fieldValue = event.detail?.recordId || event.target?.value;
        this.invoiceAccountValue = fieldValue;
        this.showInvoiceError = !fieldValue;
    }

    handleFieldChange(event){
        let indexVar = event.target.dataset.index
        let qgindexVar = event.target.dataset.qgindex
        //let fieldValue = event.currentTarget.value
        let quoteLineGroupId = event.target.dataset.qgid;
        //let fieldName = event.target.fieldName;
        let fieldValue = event.detail.recordId || event.currentTarget.value;
        let fieldName = event.target.dataset.fieldname || event.target.fieldName;

        if (fieldName === 'Invoice_Account__c') {
            this.invoiceAccountValue = fieldValue;
            this.validateInvoiceAccount(event);
        }
        
        if(fieldName === undefined)
        {
            console.log('in if --> ' + fieldName);
            fieldName = event.target.dataset.fieldname;
            fieldValue = event.detail.recordId;
            console.log('in if --> ' + fieldName);
        }
        console.log(qgindexVar+' --> '+quoteLineGroupId+' --> '+indexVar+' --> '+fieldName+' --> '+fieldValue)
        let quoteLineGroup = this.quoteLineGroups[qgindexVar];

        if (fieldName == 'Vessel_Name__c' || fieldName == 'Organisation_Name__c') {
            var flag = this.checkForDuplicate(qgindexVar, indexVar, quoteLineGroupId, fieldValue, fieldName, quoteLineGroup.newInstallations[indexVar].showVessel);
            if (flag == true) {
                fieldValue = "";
                event.target.closest("lightning-input-field").value = "";
                quoteLineGroup.newInstallations[indexVar].dupId = true;   
                quoteLineGroup.newInstallations[indexVar].disButton = true;
            }
            else {
                quoteLineGroup.newInstallations[indexVar].dupId = false; 
                quoteLineGroup.newInstallations[indexVar].disButton = false;
            }
        }
       
        if(fieldName === 'Installation_Type__c'){
            quoteLineGroup.newInstallations[indexVar].showVessel = fieldValue == 'Vessel'
        }
        quoteLineGroup.newInstallations[indexVar][fieldName] = fieldValue
    }

    checkBeforeSubmit() {
        if (!this.invoiceAccountValue) {
            this.showInvoiceError = true;
            return false; // Block form submission
        }
        return true; // Allow form submission
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

        if (!this.checkBeforeSubmit()) {
            console.error("Invoice Account is required!");
            return; 
        }
        console.log("Saving data...");

        if(quoteLineGroup.remainingInstallations > 0)
        {
            let installation = quoteLineGroup.newInstallations[indexVar]
            installation.Quote__c = this.recordId;
            installation.Quote_Line_Group__c = quoteLineGroupId;
            installation.Installation_Price__c = quoteLineGroup.installationPrice;
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
                installation.Quote__c = this.recordId;
                console.log('result --> ' + JSON.stringify(result));
                installation.Quote__r = result[0].Quote__r;
                console.log('resul1t --> ' + JSON.stringify(result));
                this.displayToast('Installation created Succesfully','Success','success','dismissable')
                installation.showVessel == installation.Installation_Type__c == 'Vessel'
                quoteLineGroup.remainingInstallations = quoteLineGroup.remainingInstallations != null ? quoteLineGroup.remainingInstallations-1:0;
                installation.rowStyle = 'highLight';
                quoteLineGroup.installations.push(installation)
                let newRec = {...result[0]}
                console.log('inst --> ' + JSON.stringify(newRec));
                this.prepareRecordForTable(newRec)
                quoteLineGroup.existingInstallations.push(newRec)
                //this.quoteLineGroups[qgindexVar].existingInstallations = [];
                this.quoteLineGroups[qgindexVar].existingInstallations = [...quoteLineGroup.existingInstallations];
                quoteLineGroup.newInstallations.splice(indexVar,1)
                console.log('qlg --> ' + JSON.stringify(quoteLineGroup.existingInstallations));
                console.log('qlgList --> ' + JSON.stringify(this.quoteLineGroups));
                this.openSpinner = false;
            })
            .catch(error => {
                console.log('error --> ' + JSON.stringify(error));
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
            case 'Change_Package':
                this.changePackage(row);
            default:
        }
    }

    changePackage1(event)
    {
        console.log('changepackage1');
        var instId = event.target.name;
        this.changeInstId = instId;
        var inst;
        this.quoteLineGroups.forEach(qlg => {
            qlg.existingInstallations.forEach(install=> {
                console.log('instId --> ' + instId);
                console.log('inst.Id --> ' + install.Id);
                console.log('compare --> ' + (instId == install.Id));
                if(instId == install.Id)
                {
                    inst = install;
                    //break;
                }
            })
        });
        console.log('inst --> ' + JSON.stringify(inst));
        fetchPackages({
            qtId : this.recordId
        }).then(result => {
            console.log('result --> ' + JSON.stringify(result));
            this.packageOptions = [];
            if(result && result.length)
            {
                for(let rec of result)
                {
                    if(inst.Package__c != rec.Id)
                    {
                        this.packageOptions.push({
                            label : rec.Name,
                            value : rec.Id
                        });
                    }
                }
            }
            this.showChangePackage = true;
            console.log('packageOptions --> ' + this.packageOptions);
        }).catch(error => {
            console.log('error --> ' + JSON.stringify(error));
        });
    }

    changePackage(row)
    {
        console.log('row --> ' + JSON.stringify(row));
        this.changeInstId = row.Id;
        var flag = false;
        /*this.quoteLineGroups.forEach(qlg => {
            if(qlg.existingInstallations != null && qlg.existingInstallations != undefined)
            {
                qlg.existingInstallations.forEach(inst => {
                    console.log('instId --> ' + inst.Id);
                    console.log('changeInstId --> ' + this.changeInstId);
                    if(inst.Id == this.changeInstId)
                    {
                        if(qlg.existingInstallations.length <= 1)
                        {
                            flag = true;
                            const evt = new ShowToastEvent({
                                title : 'Error',
                                message : 'Please select the installation from a package where the number of installations are more than 1',
                                variant : 'error'
                            });
                            this.dispatchEvent(evt);
                        }
                    }
                });
            }
        });
        if(!flag)
        {*/
            fetchPackages({
                qtId : this.recordId
            }).then(result => {
                console.log('result --> ' + JSON.stringify(result));
                this.packageOptions = [];
                if(result && result.length)
                {
                    //let resultArray = JSON.parse(result);
                    for(let rec of result)
                    {
                        if(row.Package__c != rec.Id)
                        {
                            this.packageOptions.push({
                                label : rec.Name,
                                value : rec.Id
                            });
                        }
                    }
                }
                this.showChangePackage = true;
                console.log('packageOptions --> ' + this.packageOptions);
            }).catch(error => {
                console.log('error --> ' + error);
            });
        //}
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

    closeChangePackage()
    {
        this.showChangePackage = false;
    }

    handleRowSelection(event)
    {
        this.selectedRows=event.detail.selectedRows;
        console.log('selectedRows --> ' + JSON.stringify(this.selectedRows));
    }

    savePackageInfo(event)
    {
        var selectedRecords = this.selectedRows; //this.template.querySelector('[data-id="ChangePackTable"]').getSelectedRows();
        var quoteLineGrpList = this.quoteLineGroups;
        var remInstallations;
        for(var qlg of quoteLineGrpList)
        {
            console.log('packId --> ' + qlg.Package__c + 'sel Id --> ' + this.selectedPackage);
            if(qlg.Package__c == this.selectedPackage)
            {
                remInstallations = qlg.remainingInstallations;
            }
        }
        console.log('remInst --> ' + remInstallations);
        if(remInstallations >= 1 || selectedRecords.length == 1){
            console.log('selectedRecords are ', selectedRecords);
            saveInstallationRecord({
                packId: this.selectedPackage,
                instId: this.changeInstId,
                swapInstId: selectedRecords.length == 1 ? selectedRecords[0].Id : null
            }).then(result => {
                const evt = new ShowToastEvent({
                    title: 'Saved Successfully',
                    message: 'Package updated Successfully',
                    variant: 'success',
                });
                this.dispatchEvent(evt);
                console.log('before close');
                this.showChangePackage = false;
                //this.refreshPage();
                this.quoteLineGroups = [];
                this.fetchInstallations();
            }).catch(error => {
                console.log('error --> ' + JSON.stringify(error));
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

    editInstallation(event)
    {
        console.log('name --> ' + event.target.name);
        this.currentInstallIdToEdit = event.target.name;
        this.showProductsInfo = false;
        this.showInstallationDetail = true;
        this.openModal = true
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