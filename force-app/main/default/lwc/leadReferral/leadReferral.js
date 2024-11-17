import { api, LightningElement, track, wire } from 'lwc';
import validateLead from '@salesforce/apex/LeadReferralController.validateLead';
import getCustomerTypes from '@salesforce/apex/LeadReferralController.getCustomerTypes';
import { NavigationMixin } from 'lightning/navigation';
import FORM_FACTOR from '@salesforce/client/formFactor';

export default class LeadReferral extends NavigationMixin(LightningElement) {
    @track selectedMultiSelectValues;
    @track productList = [];
    @track showSpinner = false;
    @track fields = {
        firstName: '',
        lastName: '',
        email: '',
        phone: '',
        companyType: '',
        existingCustomer: '',
        companyName: '',
        products: '',
        website: '',
        AccountURL: '',
        salesPersonName: '',
        salesPersonEmail: '',
        vesselDetails: '',
        customerBackground: '',
        formType: ''
    };

    message = '';
    @track IsLRcustomers = [];
    @track employees = [
        { label: '1', value: '1' },
        { label: '2-50', value: '2-50' },
        { label: '50-200', value: '50-200' },
        { label: '200-1000', value: '200-1000' },
        { label: '1000-10000', value: '1000-10000' },
        { label: '10000+', value: '10000+' }
    ];

    @track error;
    @track name;
    @track isMobile = false;

    value = [];
    get productRange() {
        return [
            { label: 'Learning Management System/Learning Assessment (OLP)', value: 'Learning & Assessment' },
            { label: 'Fleet Management Solution (TM Master)', value: 'Fleet Management System (TM Master)' },
            { label: 'Crewing/HR Management System (Compas)', value: 'Crew Management/HR System (Compas)' },
            { label: 'Marine Regulations (DanDocs)', value: 'Marine Regulations' },
            { label: 'Unknown - See Lead Description', value: 'Other' }
        ];
    }

    handleChange(event) {
        this.productList = event.detail.value;
    }

    connectedCallback() {
        console.log('In connected call back');
        this.handleFormType();

        getCustomerTypes()
            .then(result => {
                let typeData = JSON.parse(result).map(type => ({ label: type, value: type }));
                this.IsLRcustomers = typeData;
            })
            .catch(error => {
                console.error('Error fetching customer types:', error);
            });

        console.log('formFactor --> ' + FORM_FACTOR);
        this.isMobile = FORM_FACTOR === 'Small';
    }

    handleFormType() {
        const queryParams = this.getQueryParameters();
        const type = queryParams.type || '';
        this.fields.formType = ['ContactSales', 'RequestDemo', 'LeadWebPageOrigin'].includes(type) ? type : '';
    }

    fieldChange(event) {
        const fieldName = event.target.dataset.name;
        const fieldValue = event.target.value;
        this.fields[fieldName] = fieldValue;

        if (fieldName === 'name' && fieldValue) {
            this.handleNameField(fieldValue);
        }

        if (fieldName === 'website') {
            this.validateWebsiteField();
        }

        if (fieldName === 'companyName') {
            this.validateCompanyNameField();
        }
    }

    handleNameField(fullName) {
        const nameParts = fullName.trim().split(' ');
        this.fields.firstName = nameParts[0] || '';
        this.fields.lastName = nameParts.slice(1).join(' ') || '';
    }

    validateWebsiteField() {
        const websiteField = this.template.querySelector('lightning-input[data-name="website"]');
        const websiteValue = this.fields.website;
        if (!websiteValue.includes('.') || websiteValue.includes(' ')) {
            websiteField.setCustomValidity('Please enter a valid website address.');
        } else {
            websiteField.setCustomValidity('');
        }
        websiteField.reportValidity();
    }

    validateCompanyNameField() {
        const companyNameField = this.template.querySelector('lightning-input[data-name="companyName"]');
        const companyNameValue = this.fields.companyName;
        if (companyNameValue.length < 3) {
            companyNameField.setCustomValidity('Company Name must be at least 3 characters.');
        } else {
            companyNameField.setCustomValidity('');
        }
        companyNameField.reportValidity();
    }

    submitLead() {
        this.showSpinner = true;
        let isValid = this.validateForm();

        if (isValid) {
            this.fields.products = this.productList;
            validateLead({ formData: JSON.stringify(this.fields) })
                .then(() => {
                    this.showSpinner = false;
                    console.log('Lead submitted successfully.');
                    window.location.href = '/apex/LeadSubmissionThankYou';
                })
                .catch(error => {
                    this.showSpinner = false;
                    console.error('Error submitting lead:', error);
                });
        } else {
            this.showSpinner = false;
        }
    }

    validateForm() {
        let isValid = true;

        const inputFields = [...this.template.querySelectorAll('lightning-input')];
        inputFields.forEach(field => {
            if (!field.checkValidity()) {
                field.reportValidity();
                isValid = false;
            }
        });

        const checkboxGroup = this.template.querySelector('lightning-checkbox-group');
        if (checkboxGroup && !checkboxGroup.checkValidity()) {
            checkboxGroup.reportValidity();
            isValid = false;
        }

        const radioGroup = this.template.querySelector('lightning-radio-group');
        if (radioGroup && !radioGroup.checkValidity()) {
            radioGroup.reportValidity();
            isValid = false;
        }

        return isValid;
    }

    getQueryParameters() {
        const params = {};
        const search = location.search.substring(1);
        if (search) {
            search.split('&').forEach(pair => {
                const [key, value] = pair.split('=');
                params[key] = decodeURIComponent(value || '');
            });
        }
        return params;
    }

    handleOnItemSelected(event) {
        this.selectedMultiSelectValues = event.detail
            .map(item => item.value)
            .join(', ');
    }
}