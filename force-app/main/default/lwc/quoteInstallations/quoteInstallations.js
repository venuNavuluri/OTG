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
import saveInstallationToQLG from '@salesforce/apex/QuoteInstallationController.saveInstallationToQLG'; // NEW
import { NavigationMixin } from 'lightning/navigation';
const FIELDS = ['Name','SBQQ__Account__c','SBQQ__Opportunity2__c'];
const GETRECORDFIELDS = ['SBQQ__Quote__c.Name','SBQQ__Quote__c.SBQQ__Account__r.Name', 'SBQQ__Quote__c.SBQQ__Account__r.Account_ID__c','SBQQ__Quote__c.SBQQ__Opportunity2__r.Name', 'SBQQ__Quote__c.SBQQ__Opportunity2__r.Opportunity_ID__c']
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import UploadInstallationErrorMessage from '@salesforce/label/c.Upload_Installations_Error_Message';
import { encodeDefaultFieldValues } from "lightning/pageReferenceUtils";
import LightningConfirm from 'lightning/confirm';

const actions = [
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

    // ---------- OLD Package swap state (left as-is, not used by new flow) ----------
    @track packageOptions = [];
    @track showChangePackage = false; // reused for new modal too
    @track selectedPackage;
    @track showInstallations = false;
    @track installations = [];
    @track changeInstId;
    @track selectedRows = [];
    @track renderChangePackage = false; // reused (true if there are options to render)
    @track showInvoiceError = false;

    // ---------- NEW: QLG selection state for Change Package flow ----------
    @track qlgOptions = [];       // radio options of eligible QLGs
    @track selectedQLG = null;    // selected QLG Id

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
                    typeAttributes: { rowActions: this.getRowActions },
                }
    ]

    filter;

    get acceptedFormats() {
        return ['.csv'];
    }

    handleUploadFinished(event) {
        this.openSpinner = true;
        let quoteLineGroupId = event.target.dataset.lgid;
        let qgindexVar = event.target.dataset.qgindex;
        let quoteLineGroup = this.quoteLineGroups[qgindexVar]
        const uploadedFiles = event.detail.files;
        createInstallations({
            conVerId : uploadedFiles[0].contentVersionId,
            qtId : this.recordId,
            qlgId : quoteLineGroupId,
            instPrice : quoteLineGroup.installationPrice
        }).then(result => {
                if(result != 'Failed') {
                    const event = new ShowToastEvent({
                        title: 'Success',
                        message: 'Installations Created Successfully.',
                        variant: 'success',
                        mode: 'dismissable'
                    });
                } else {
                    const event = new ShowToastEvent({
                        title: 'Failed',
                        message: 'Error occured while creating installations.',
                        variant: 'error',
                        mode: 'dismissable'
                    });
                }
                this.openSpinner = false;
            }).catch(error => {
                console.log('error --> ' + JSON.stringify(error));
                this.message = UploadInstallationErrorMessage;
                this.showMessage = true;
                this.openSpinner = false;
            });
    }

    refreshPage(event) {
        window.location.reload();
    }

    createRecordsBulk(event) {
        this.isModalOpen = true;
        this.qlgId = event.target.dataset.lgid;
        this.qgIndex=event.target.dataset.qgindex;
        this.instList = this.quoteLineGroups[this.qgIndex].existingInstallations;
        this.quoteLineGroups[this.qgIndex].existingInstallations = [];
        this.remainingQty = this.quoteLineGroups[this.qgIndex].remainingInstallations;
    }

    handleCountChange(e) {
        this.count = e.detail.value;
        if(this.remainingQty >= this.count) {
            this.disableSave = false;
        } else {
            this.disableSave = true;
        }
    }

    closeModalPopup() {
        this.isModalOpen = false;
    }

    closeInvoiceModal() {
        this.createInvoice = false;
    }

    createInstallations(event) {
        event.preventDefault();
        let fields = event.detail.fields;
        let quoteLineGroup = this.quoteLineGroups[this.qgIndex];

        this.openSpinner = true;
        createRecords({
            quoteId : this.recordId,
            quoteGrpId : this.qlgId,
            count : this.count,
            delvContact : fields.Delivery_Contact__c,
            invAcc : fields.Invoice_Account__c,
            client : fields.Client__c
        }).then(result => {
            for(let i = 0; i < result.length; i++) {
                this.prepareRecordForTable(result[i]);
                this.instList.push(result[i]);
            }
            quoteLineGroup.existingInstallations = this.instList;
            quoteLineGroup.remainingInstallations = quoteLineGroup.remainingInstallations - result.length;
            if(quoteLineGroup.remainingInstallations <= 0) {
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
                let resultArray = JSON.parse(result);
                let qlgArray = [];
                for(let listItem of resultArray){
                    let quoteLineGroup = listItem.qlg;
                    quoteLineGroup.installationPrice = listItem.installationPrice;
                    quoteLineGroup.userPrice = listItem.userPrice;
                    quoteLineGroup.installations = [];
                    let packInstList = (listItem.pack != null && listItem.pack != undefined) ? listItem.pack.Installations__r?.records : [];
                    if(!packInstList) { packInstList = []; }
                    const installedCount = (listItem.pack && listItem.pack.Installations__r && listItem.pack.Installations__r.totalSize != null)
                        ? listItem.pack.Installations__r.totalSize
                        : packInstList.length;
                    for(let inst of packInstList){ quoteLineGroup.installations.push(inst); }
                    quoteLineGroup.remainingInstallations = quoteLineGroup.Installation_Quantity__c != null
                        ? Math.max(quoteLineGroup.Installation_Quantity__c - installedCount, 0)
                        : 0;
                    quoteLineGroup.existingInstallations = []
                    for(let installExisting of quoteLineGroup.installations){
                        this.prepareRecordForTable(installExisting)
                        quoteLineGroup.existingInstallations.push(installExisting)
                    }
                    if(quoteLineGroup.remainingInstallations > 0 || quoteLineGroup.Installation_Quantity__c ==  null){
                        quoteLineGroup.newInstallations = this.addInstallation(1,quoteLineGroup.Id);
                    }
                    if(quoteLineGroup.SBQQ__LineItems__r?.records) {
                        let prodList = [];
                        for(let qLine of quoteLineGroup.SBQQ__LineItems__r.records){
                            let prdKey = qLine.SBQQ__Product__r.ProductCode+' : '+qLine.SBQQ__ProductName__c
                            if(!prodList.includes(prdKey)){ prodList.push(prdKey) }
                        }
                        quoteLineGroup.productsString = prodList.length ? prodList.join(',') : '';
                    }
                    qlgArray.push(quoteLineGroup);
                }
                this.quoteLineGroups = qlgArray;
            }
            if(this.quoteLineGroups.length > 1) {
                this.renderChangePackage = true;
            }
        })
        .catch(error => {
            console.log('error --> ' + JSON.stringify(error));
        })
    }

    prepareRecordForTable(installExisting) {
        installExisting.recordUrl = '/lightning/r/Installation__c/' + installExisting.Id + '/view';
        const isVessel = installExisting.Installation_Type__c === 'Vessel';
        if (installExisting.Vessel_Name__c || installExisting.Organisation_Name__c) {
            installExisting.vesselOrgLink = '/lightning/r/' + (isVessel ? installExisting.Vessel_Name__c : installExisting.Organisation_Name__c) + '/view';
            installExisting.vesselOrgName = isVessel ? installExisting.Vessel_Name__r?.Name : installExisting.Organisation_Name__r?.Name;
        }
        if (installExisting.Invoice_Account__c) {
            installExisting.invAcctLink = '/lightning/r/' + installExisting.Invoice_Account__c + '/view';
            installExisting.invAcctName = installExisting.Invoice_Account__r.Name;
        }
        if (installExisting.Client__c) {
            installExisting.clientLink = '/lightning/r/' + installExisting.Client__c + '/view';
            installExisting.clientName = installExisting.Client__r?.Name;
        }
        if (installExisting.Delivery_Contact__c) {
            installExisting.deliveryContactLink = '/lightning/r/' + installExisting.Delivery_Contact__c + '/view';
            installExisting.deliveryContactName = installExisting.Delivery_Contact__r.Name;
        }
        if (installExisting.Quote__c === this.recordId) {
            installExisting.rowStyle = 'highLight';
        }
        if (installExisting.Quote__c === undefined) {
            installExisting.Quote__r = { Name: '' };
        }

        // NEW: hide Change Package when status is In Progress
        const status = (installExisting.Change_Package_Status__c || '').toLowerCase();
        installExisting.canChangePackage = status !== 'In Progress';

        // Normalize and compute flags
        const raw = (installExisting.Change_Package_Status__c || '').toLowerCase().trim();
        const inProgress = raw === 'in progress';

        // Show/hide and disable flags for the template
        installExisting.canChangePackage = !inProgress;
        installExisting.disableChangePackage = inProgress;
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
                value: this.quoteInfo?.fields?.SBQQ__Account__r?.value?.id
            }
        ];
    }

    handleFlowStatusChange(event) {
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
        var matchVessel = false;
        this.quoteLineGroups.forEach(existPackage => {
            var existInstall = existPackage.existingInstallations;
            existInstall.forEach(element => {
                if ((isVessel && element.Vessel_Name__c == exVesselId) || (!isVessel && element.Organisation_Name__c == exVesselId) && exVesselId != "") {
                    matchVessel = true;
                }
            });
        });
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
        let quoteLineGroupId = event.target.dataset.qgid;
        let fieldValue = event.detail.recordId || event.currentTarget.value;
        let fieldName = event.target.dataset.fieldname || event.target.fieldName;

        if (fieldName === 'Invoice_Account__c') {
            this.invoiceAccountValue = fieldValue;
            this.validateInvoiceAccount(event);
        }
        
        if(fieldName === undefined) {
            fieldName = event.target.dataset.fieldname;
            fieldValue = event.detail.recordId;
        }
        let quoteLineGroup = this.quoteLineGroups[qgindexVar];

        if (fieldName == 'Vessel_Name__c' || fieldName == 'Organisation_Name__c') {
            var flag = this.checkForDuplicate(qgindexVar, indexVar, quoteLineGroupId, fieldValue, fieldName, quoteLineGroup.newInstallations[indexVar].showVessel);
            if (flag == true) {
                fieldValue = "";
                event.target.closest("lightning-input-field").value = "";
                quoteLineGroup.newInstallations[indexVar].dupId = true;   
                quoteLineGroup.newInstallations[indexVar].disButton = true;
            } else {
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
            return false;
        }
        return true;
    }
    
    handleNewAccCreate(){
        var accId = this.accId[0];
        const defaultValues = encodeDefaultFieldValues({
            ParentId : accId,
            B2B_Account__c : accId
        });
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

    closeMessageModal() {
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
        let quoteLineGroup = this.quoteLineGroups[qgindexVar]

        if (!this.checkBeforeSubmit()) {
            console.error("Invoice Account is required!");
            return; 
        }

        if(quoteLineGroup.remainingInstallations > 0) {
            let installation = quoteLineGroup.newInstallations[indexVar]
            installation.Quote__c = this.recordId;
            installation.Quote_Line_Group__c = quoteLineGroupId;
            installation.Installation_Price__c = quoteLineGroup.installationPrice;
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
                installation.Quote__r = result[0].Quote__r;
                this.displayToast('Installation created Succesfully','Success','success','dismissable')
                installation.showVessel == installation.Installation_Type__c == 'Vessel'
                quoteLineGroup.remainingInstallations = quoteLineGroup.remainingInstallations != null ? quoteLineGroup.remainingInstallations-1:0;
                installation.rowStyle = 'highLight';
                quoteLineGroup.installations.push(installation)
                let newRec = {...result[0]}
                this.prepareRecordForTable(newRec)
                quoteLineGroup.existingInstallations.push(newRec)
                this.quoteLineGroups[qgindexVar].existingInstallations = [...quoteLineGroup.existingInstallations];
                quoteLineGroup.newInstallations.splice(indexVar,1)
                this.openSpinner = false;
            })
            .catch(error => {
                console.log('error --> ' + JSON.stringify(error));
                installation.showVessel == installation.Installation_Type__c == 'Vessel'
                this.displayToast('Error Creating this Installation','Error','error','dismissable')
                this.openSpinner = false;
            })
        } else {
            this.message = "All installation records for this Quote Line Group have already been created";
            this.showMessage = true;
        }
    }
    getRowActions(row, doneCallback) {
        const actions = [];

        // Always allow Edit
        actions.push({ label: 'Edit', name: 'edit' });
        console.log('Row status', installExisting.Id, installExisting.Change_Package_Status__c);
        // Only allow Change Package if not "In Progress"
        if (row.Change_Package_Status__c !== 'In Progress') {
            actions.push({ label: 'Change Package', name: 'Change_Package' });
        }

        // Return actions
        doneCallback(actions);  
    }
    get selectedTargetQLG() {
        return (this.quoteLineGroups || []).find(q => q.Id === this.selectedQLG);
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
                this.changePackage(row); // unified entry
            default:
        }
    }

    // --------- NEW: used by table menu (not datatable) to locate row then call unified changePackage ----------
    changePackageFromMenu(event) {
        const instId = event.target?.name;
        if (!instId) return;
        let found = null;
        for (const qlg of this.quoteLineGroups) {
            const arr = qlg?.existingInstallations || [];
            const hit = arr.find(r => r.Id === instId);
            if (hit) {
                // add current QLG ref to row (for filtering out current)
                if (!hit.Quote_Line_Group__c && qlg.Id) {
                    hit.Quote_Line_Group__c = qlg.Id;
                }
                found = hit;
                break;
            }
        }
        if (!found) {
            this.displayToast('Installation not found in current view','Error','error','dismissable');
            return;
        }
        // FINAL SAFETY: block when status is In Progress
        const raw = (found.Change_Package_Status__c || '').toLowerCase().trim();
        if (raw === 'in progress') {
            this.displayToast('Change Package is in progress for this installation. Please wait until it completes.','Action blocked','warning','dismissable');
            return;
        }

        // Proceed with the normal flow
        // Ensure the row carries its current QLG id for filtering
        if (!found.Quote_Line_Group__c && found.Quote__r?.Id) {
            // nothing needed here unless you rely on it; existing code is fine
        }
        this.changePackage(found);
    }

    get isQLGSaveDisabled() {
        return !this.renderChangePackage || !this.selectedQLG;
    }

    // --------- NEW: unified Change Package flow using QLG remaining capacity ----------
    changePackage(row) {
        // Installation being moved
        this.changeInstId = row.Id;

        // Infer current QLG id
        const currentQLGId = row.Quote_Line_Group__c || row.Quote_Line_Group__r?.Id;

        // Build eligible QLG options from already-loaded this.quoteLineGroups
        // Rule: remainingInstallations > 0 AND not the current QLG
        const options = (this.quoteLineGroups || [])
            .filter(qlg =>
                (qlg?.remainingInstallations || 0) > 0 &&
                qlg?.Id !== currentQLGId
            )
            .map(qlg => ({
                label: `${qlg.Name}  •  Remaining: ${qlg.remainingInstallations}`,
                value: qlg.Id
            }));

        this.qlgOptions = options;
        this.selectedQLG = null;
        this.renderChangePackage = this.qlgOptions.length > 0;
        this.showChangePackage = true;

        if (!this.renderChangePackage) {
            this.displayToast('No eligible packages', 'There are no packages with remaining installation capacity.', 'warning', 'dismissable');
        }
    }

    // NEW: handle radio change
    handleQLGSelected(event) {
        this.selectedQLG = event.detail.value;
    }

    // NEW: save move (overwrite Quote, QLG, Package based on target QLG)
    async saveQLGChange() {
        if (!this.selectedQLG) {
            this.displayToast('Please select a Quote Line Group', 'Selection required', 'error', 'dismissable');
            return;
        }
        if (!this.changeInstId) {
            this.displayToast('Installation not found', 'Unexpected state', 'error', 'dismissable');
            return;
        }

        // Locate the source installation row (to show the current package name in the confirm)
        let sourceRow = null;
        for (const qlg of this.quoteLineGroups) {
            const arr = qlg?.existingInstallations || [];
            const hit = arr.find(r => r.Id === this.changeInstId);
            if (hit) { sourceRow = hit; break; }
        }

        // Resolve names (fallbacks are friendly)
        const instName = sourceRow?.Name || 'this installation';
        const fromPkg = (sourceRow?.Package__r?.Name) || (sourceRow?.Package__c ? sourceRow.Package__c : 'No Package');
        const targetQLG = this.selectedTargetQLG;
        const toPkg = (targetQLG?.Package__r?.Name) || (targetQLG?.Package__c ? targetQLG.Package__c : 'Target Package');

        // Ask for confirmation
        const confirmed = await LightningConfirm.open({
            message: `You're about to move ${instName} from package "${fromPkg}" to package "${toPkg}".\n\nAre you sure you want to proceed?`,
            label: 'Confirm Package Change',
            theme: 'warning', // yellow header
            variant: 'header'
        });
        if (!confirmed) {
            return; // user cancelled
        }

        this.openSpinner = true;
        try {
            await saveInstallationToQLG({
                instId: this.changeInstId,
                targetQlgId: this.selectedQLG,
                quoteId: this.recordId
            });
            this.displayToast('Installation moved successfully', 'Saved Successfully', 'success', 'dismissable');
            this.showChangePackage = false;
            // Refresh groups
            this.quoteLineGroups = [];
            this.fetchInstallations();
        } catch (error) {
            console.log('error --> ' + JSON.stringify(error));
            const msg = (error?.body?.message) || 'Failed to move installation';
            this.displayToast(msg, 'Error', 'error', 'dismissable');
        } finally {
            this.openSpinner = false;
        }
    }

    // Existing (older) package-change helpers left intact but unused by new flow
    changePackage1(event) {
        // Kept to avoid accidental reference breaks—no longer used in the UI.
        // Intentionally left as-is; new UI calls changePackageFromMenu instead.
        console.log('changepackage1 (deprecated path)');
    }

    // keep existing package-related methods untouched (fetchPackages, getPackageInfo, handleSelected, handleRowSelection, savePackageInfo, etc.)
    handleSelected(event) {
        this.selectedPackage = event.target.value;
        getPackageInfo({
            packId : this.selectedPackage
        }).then(result => {
            if(result && result[0]){
                if(result[0].Installation_Quantity__c <= (result[0].Installations__r ? result[0].Installations__r.length : 0)) {
                    this.installations = result[0].Installations__r || [];
                    this.showInstallations = true;
                } else {
                    this.installations = [];
                    this.showInstallations = false;
                }
            } else {
                this.installations = [];
                this.showInstallations = false;
            }
        }).catch(error => {
            console.log('error --> ' + error);
        });
    }

    closeChangePackage() {
        this.showChangePackage = false;
    }

    handleRowSelection(event) {
        this.selectedRows=event.detail.selectedRows;
    }

    savePackageInfo(event) {
        // Left intact; not used by the new QLG flow
        var selectedRecords = this.selectedRows;
        var quoteLineGrpList = this.quoteLineGroups;
        var remInstallations;
        for(var qlg of quoteLineGrpList) {
            if(qlg.Package__c == this.selectedPackage) {
                remInstallations = qlg.remainingInstallations;
            }
        }
        if(remInstallations >= 1 || selectedRecords.length == 1){
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
                this.showChangePackage = false;
                this.quoteLineGroups = [];
                this.fetchInstallations();
            }).catch(error => {
                console.log('error --> ' + JSON.stringify(error));
            });
        }
        else if(selectedRecords.length > 1) {
            const evt = new ShowToastEvent({
                title: 'More records selected',
                message: 'You have to select only one record',
                variant: 'error',
            });
            this.dispatchEvent(evt);
        }
        else {
            const evt = new ShowToastEvent({
                title: 'No records selected',
                message: 'You have to select atleast one record',
                variant: 'error',
            });
            this.dispatchEvent(evt);
        }
    }

    editInstallation(event) {
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