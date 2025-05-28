import { LightningElement, track, wire } from 'lwc';
import getCertificates from '@salesforce/apex/WebToCaseController.getCertificates';
import getModules from '@salesforce/apex/WebToCaseController.getModules';
import createCase from '@salesforce/apex/WebToCaseController.createCase';
import getCountries from '@salesforce/apex/WebToCaseController.getCountries';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CourseCaseForm extends LightningElement {
    @track certificates = [];
    @track modules = [];
    @track selectedCertificateId = '';
    @track selectedModuleIds = [];
    @track selectedModuleNames = [];
    @track requestorFirstName = '';
    @track requestorLastName = '';
    @track requestorEmail = '';
    @track applicantFirstName = '';
    @track applicantLastName = '';
    @track jobTitle = '';
    @track applicantEmail = '';
    @track olpUsername = '';
    @track olpCompanyName = '';
    @track vesselName = '';
    @track vesselIMO = '';
    @track dob = '';
    @track otherDetails = '';
    @track invoiceAddress1 = '';
    @track invoiceTownCity = '';
    @track invoiceState = '';
    @track invoiceZipcode = '';
    @track invoiceCompanyName = '';
    @track invoiceEmail = '';
    @track isLoading = false;
    @track countries = [];
    @track selectedCountryId = '';
    @track isSubmitted = false;
    @track errors = {};
    
    caseId = '';  
    caseNumber = ''; 
    certificationName = ''; 

    @wire(getCertificates)
    wiredCertificates({ error, data }) {
        if (data) {
            console.log('Certificates fetched:', data);
            this.certificates = data.map(cert => ({ 
                label: cert.Certificate_Name__c, 
                value: cert.Id,
                Certificate_Name__c: cert.Certificate_Name__c
            }));
        } else if (error) {
            console.error('Error fetching certificates:', error);
            this.showToast('Error', 'Error fetching certificates: ' + error.body.message, 'error');
        }
    }

    @wire(getCountries)
    wiredCountries({ error, data }) {
        if (data) {
            console.log('Countries fetched:', data);
            this.countries = data.map(country => ({ label: country.Name, value: country.Id }));
        } else if (error) {
            console.error('Error fetching countries:', error);
            this.showToast('Error', 'Error fetching countries: ' + error.body.message, 'error');
        }
    }

    fetchModules() {
        if (!this.selectedCertificateId) {
            console.log('No certificate selected. Skipping module fetch.');
            return;
        }

        this.isLoading = true;
        console.log('Fetching modules for certificate ID:', this.selectedCertificateId);
        getModules({ certificateId: this.selectedCertificateId })
            .then((data) => {
                console.log('Modules fetched:', data);
                this.modules = data.map(mod => ({
                    label: mod.Module_Name__c,
                    value: mod.Id
                }));
            })
            .catch((error) => {
                console.error('Error fetching modules:', error);
                this.showToast('Error', 'Error fetching modules: ' + error.body.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleCertificateChange(event) {
        this.selectedCertificateId = event.target.value;
        console.log('Certificate selected:', this.selectedCertificateId);
        this.certificationName = this.certificates.find(cert => cert.value === this.selectedCertificateId)?.Certificate_Name__c || '';
        this.fetchModules();
        this.clearError('courseCertificate');
    }

    handleModuleChange(event) {
        const selectedModuleIds = event.detail.value;
        console.log('Modules selected:', selectedModuleIds);
        this.selectedModuleIds = selectedModuleIds;
        this.selectedModuleNames = this.modules
            .filter(module => selectedModuleIds.includes(module.value))
            .map(module => module.label);
        this.clearError('courseModules');
    }

    handleInputChange(event) {
        const fieldName = event.target.name;
        if (fieldName === 'countries') {
            this.selectedCountryId = event.target.value;
            console.log('Country selected:', this.selectedCountryId);
            this.clearError('countries');
        } else {
            this[fieldName] = event.target.value;
            console.log('Input changed:', fieldName, event.target.value);
            this.clearError(fieldName);
        }
    }

    clearError(fieldName) {
        if (this.errors[fieldName]) {
            this.errors = {...this.errors};
            delete this.errors[fieldName];
        }
    }

    validateFields() {
        this.errors = {};
        let isValid = true;

        const requiredFields = [
            { name: 'requestorEmail', label: 'Requestor Email' },
            { name: 'applicantFirstName', label: 'Applicant First Name' },
            { name: 'applicantLastName', label: 'Applicant Last Name' },
            { name: 'jobTitle', label: 'Job Title' },
            { name: 'applicantEmail', label: 'Applicant Email' },
            { name: 'vesselName', label: 'Vessel Name' },
            { name: 'vesselIMO', label: 'Vessel IMO' },
            { name: 'dob', label: 'Date of Birth' },
            { name: 'invoiceCompanyName', label: 'Invoice Company Name' },
            { name: 'invoiceEmail', label: 'Invoice Email' },
            { name: 'invoiceAddress1', label: 'Address 1' }
        ];

        requiredFields.forEach(field => {
            if (!this[field.name]) {
                this.errors[field.name] = `${field.label} is required`;
                isValid = false;
            }
        });

        if (this.requestorEmail && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(this.requestorEmail)) {
            this.errors.requestorEmail = 'Please enter a valid email address';
            isValid = false;
        }

        if (this.applicantEmail && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(this.applicantEmail)) {
            this.errors.applicantEmail = 'Please enter a valid email address';
            isValid = false;
        }

        if (this.invoiceEmail && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(this.invoiceEmail)) {
            this.errors.invoiceEmail = 'Please enter a valid email address';
            isValid = false;
        }

        if (!this.selectedCertificateId) {
            this.errors.courseCertificate = 'Please select a certificate';
            isValid = false;
        }

        if (this.selectedModuleIds.length === 0) {
            this.errors.courseModules = 'Please select at least one module';
            isValid = false;
        }

        if (!this.selectedCountryId) {
            this.errors.countries = 'Please select a country';
            isValid = false;
        }

        return isValid;
    }

    handleSubmit() {
        console.log('Form submitted');
        
        if (!this.validateFields()) {
            const firstError = Object.values(this.errors)[0];
            if (firstError) {
                this.showToast('Validation Error', firstError, 'error');
            }
            return;
        }

        this.isLoading = true;
        console.log('Submitting form with data:', {
            requestorEmail: this.requestorEmail,
            requestorFirstName: this.requestorFirstName,
            requestorLastName: this.requestorLastName,
            applicantFirstName: this.applicantFirstName,
            applicantLastName: this.applicantLastName,
            jobTitle: this.jobTitle,
            applicantEmail: this.applicantEmail,
            olpUsername: this.olpUsername,
            olpCompanyName: this.olpCompanyName,
            courseCertificateId: this.selectedCertificateId,
            courseModules: this.selectedModuleNames.join('; '), 
            courseCertificateName: this.certificationName,
            vesselName: this.vesselName,
            vesselIMO: this.vesselIMO,
            dob: this.dob,
            otherDetails: this.otherDetails,
            invoiceAddress1: this.invoiceAddress1,
            invoiceTownCity: this.invoiceTownCity,
            invoiceState: this.invoiceState,
            invoiceZipcode: this.invoiceZipcode,
            countries: this.selectedCountryId,
            invoiceCompanyName: this.invoiceCompanyName,
            invoiceEmail: this.invoiceEmail
        });

        createCase({
            caseData: {
                requestorEmail: this.requestorEmail,
                requestorFirstName: this.requestorFirstName,
                requestorLastName: this.requestorLastName,
                applicantFirstName: this.applicantFirstName,
                applicantLastName: this.applicantLastName,
                jobTitle: this.jobTitle,
                applicantEmail: this.applicantEmail,
                olpUsername: this.olpUsername,
                olpCompanyName: this.olpCompanyName,
                courseCertificateId: this.selectedCertificateId,
                courseModules: this.selectedModuleNames.join('; '),
                courseCertificateName: this.certificationName,
                vesselName: this.vesselName,
                vesselIMO: this.vesselIMO,
                dob: this.dob,
                otherDetails: this.otherDetails,
                invoiceAddress1: this.invoiceAddress1,
                invoiceTownCity: this.invoiceTownCity,
                invoiceState: this.invoiceState,
                invoiceZipcode: this.invoiceZipcode,
                countries: this.selectedCountryId,
                invoiceCompanyName: this.invoiceCompanyName,
                invoiceEmail: this.invoiceEmail
            }
        })
            .then((caseId) => {
                console.log('Case created successfully with ID:', caseId);
                this.caseId = caseId;
                this.isSubmitted = true;
                this.showToast('Success', 'Case created successfully. Case ID: ' + caseId, 'success');
                this.resetForm();
            })
            .catch((error) => {
                console.error('Error creating case:', error);
                this.showToast('Error', 'Error creating case: ' + error.body.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    resetForm() {
        console.log('Resetting form data.');
        this.selectedCertificateId = '';
        this.selectedModuleIds = [];
        this.selectedModuleNames = [];
        this.requestorFirstName = '';
        this.requestorLastName = '';
        this.requestorEmail = '';
        this.applicantFirstName = '';
        this.applicantLastName = '';
        this.jobTitle = '';
        this.applicantEmail = '';
        this.olpUsername = '';
        this.olpCompanyName = '';
        this.vesselName = '';
        this.vesselIMO = '';
        this.dob = '';
        this.otherDetails = '';
        this.invoiceAddress1 = '';
        this.invoiceTownCity = '';
        this.invoiceState = '';
        this.invoiceZipcode = '';
        this.countries = '';
        this.invoiceCompanyName = '';
        this.invoiceEmail = '';
        this.selectedCountryId = '';
        this.errors = {};
    }

    showToast(title, message, variant) {
        console.log('Showing toast:', title, message, variant);
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant,
            })
        );
    }
}