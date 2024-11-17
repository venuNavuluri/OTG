import { api,LightningElement,track,wire } from 'lwc';
import validateLead from '@salesforce/apex/leadSubmissionController.validateLead';
import getCustomerTypes from '@salesforce/apex/leadSubmissionController.getCustomerTypes';
import { NavigationMixin } from 'lightning/navigation';
import FORM_FACTOR from '@salesforce/client/formFactor';

export default class LeadSubmission extends NavigationMixin(LightningElement) {
    @track selectedMultiSelectValues;
    @track productList;
    @track showSpinner = false;
    @track fields = {
        firstName:'',
        lastName:'',
        email:'',
        jobTitle:'',
        phone:'',
        companyType:'',
        companyName:'',
        products:'',
        website:'',
        hearAboutUs: '',
        formType:''
    }
    message = '';
    @track customerTypes = [];
    @track employees = [
        { label: '1', value: '1'},
        { label: '2-50', value: '2-50'},
        { label: '50-200', value: '50-200'},
        { label: '200-1000', value: '200-1000'},
        { label: '1000-10000', value: '1000-10000'},
        { label: '10000+', value: '10000+'}
    ]

    @track error ;
    @track name;
    @track isMobile = false;

    value = [];
    get productRange() {
        return [
            {label:'Learning & Assessment',value:'Learning & Assessment'},
            {label:'Fleet Management System (TM Master)',value:'Fleet Management System (TM Master)'},
            {label:'Crew Management/HR System (Compas)',value:'Crew Management/HR System (Compas)'},
            {label:'Marine Regulations',value:'Marine Regulations'}
        ];
    }

    handleChange(event) {
        let products = [];
        for (let a in event.detail.value){
            products.push(event.detail.value[a]);
        }
        this.products = products;
    }

    connectedCallback(){
        console.log("In connected call back");
        if (this.getQueryParameters().type == 'ContactSales'){
            this.fields.formType = 'ContactSales';
        } else if (this.getQueryParameters().type == 'RequestDemo'){ 
            this.fields.formType = 'RequestDemo';
        }
        getCustomerTypes()
        .then(result => {
            let typeData = [];
            result = JSON.parse(result);
            for (let a in result){
                typeData.push({ label: result[a], value: result[a]})
            }
            this.customerTypes = typeData;
        })
        .catch(error => {
    
        });
        console.log('Check');
        console.log('formfactor --> ' + FORM_FACTOR);
        if(FORM_FACTOR == 'Small')
        {
            this.isMobile = true;
        }
   }    

    fieldChange(event){
        this.fields[event.target.dataset.name] = String(event.target.value);

        if (event.target.dataset.name == 'website')
        {
            const websiteField = this.template.querySelector('lightning-input[data-name="website"]');
            if (!this.fields[event.target.dataset.name].includes('.') || this.fields[event.target.dataset.name].includes(' '))
            {
                websiteField.setCustomValidity('Please enter a valid address');
            }
            else
            {
                websiteField.setCustomValidity('');
            }
        }

        if (event.target.dataset.name == 'companyName')
        {
            const companyNameField = this.template.querySelector('lightning-input[data-name="companyName"]');
            if (this.fields[event.target.dataset.name].length < 3)
            {
                companyNameField.setCustomValidity('Company Name must be at least 3 characters');
            }
            else
            {
                companyNameField.setCustomValidity('');
            }
        }
    }

    submitLead(event){
        this.showSpinner = true;
        let submitForm = true;
        let checkboxSelected = false;
        const inputFields = this.template.querySelectorAll('lightning-input');
        const requiredFields = Array.from(inputFields).filter((field) => field.required);

        inputFields.forEach((field) => {
            const fieldName = field.dataset.name;

            if(field.checkValidity() == false)
            {
                this.showSpinner = false;
                console.error(`Field ${fieldName} is not valid!`);
                submitForm = false;
                field.focus();
            }
        });

        var checkboxGroup = this.template.querySelector(
            'lightning-checkbox-group'
        );
        if (checkboxGroup.checkValidity()) {
            checkboxSelected = true;
        } else {
            // Shows the error immediately without user interaction
            checkboxGroup.reportValidity();
            this.checkboxSelected = false
        }
        
        requiredFields.forEach((field) => {
            let submitForm = true;
            const fieldName = field.dataset.name;
            const fieldValue = field.value;
           
            // Check if the required field is populated
            if (!fieldValue) {
                this.showSpinner = false;
                console.error(`Field ${fieldName} is required and not populated!`);
                submitForm = false;
                field.focus();
            }
        });

        if (submitForm == true && checkboxSelected == true){
            let formData = this.fields;
            formData.products = this.products;
            validateLead({
                formData : JSON.stringify(formData)
            }).then((result) => {
                this.showSpinner = false;
                console.log('success');
                window.location.href = '/apex/LeadSubmissionThankYou';
            });
        }else {
            this.showSpinner = false;
        }
    }

    getQueryParameters() {
        var params = {};
        var search = location.search.substring(1);
        if (search) {
            params = JSON.parse('{"' + search.replace(/&/g, '","').replace(/=/g, '":"') + '"}', (key, value) => {
                return key === "" ? value : decodeURIComponent(value)
            });
        }
        return params;
    }

    handleOnItemSelected (event) {
        if (event.detail) {
            this.selectedMultiSelectValues = '';
            let self = this;
            
        event.detail.forEach (function (eachItem) {
                self.selectedMultiSelectValues += eachItem.value + ', ';
        });
        }
    }
}