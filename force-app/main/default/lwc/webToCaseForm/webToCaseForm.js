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
    
    caseId = '';  
    caseNumber = ''; 
    certificationName = ''; 

    // Fetch certificates
    @wire(getCertificates)
    wiredCertificates({ error, data }) {
        if (data) {
            console.log('Certificates fetched:', data);
            this.certificates = data.map(cert => ({ label: cert.Name, value: cert.Id }));
        } else if (error) {
            console.error('Error fetching certificates:', error);
            this.showToast('Error', 'Error fetching certificates: ' + error.body.message, 'error');
        }
    }

    // Fetch countries
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

    // Fetch modules based on selected certificate
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
                    label: mod.Name,
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

    // Handle certificate change
    handleCertificateChange(event) {
        this.selectedCertificateId = event.target.value;
        console.log('Certificate selected:', this.selectedCertificateId);
        this.certificationName = this.certificates.find(cert => cert.value === this.selectedCertificateId)?.label || '';
        this.fetchModules();
    }

    // Handle module change
    handleModuleChange(event) {
        const selectedModuleIds = event.detail.value;
        console.log('Modules selected:', selectedModuleIds);
        this.selectedModuleIds = selectedModuleIds;
        this.selectedModuleNames = this.modules
            .filter(module => selectedModuleIds.includes(module.value))
            .map(module => module.label);
    }

    // Handle form input changes
    handleInputChange(event) {
        const fieldName = event.target.name;
        if (fieldName === 'countries') {
            this.selectedCountryId = event.target.value;
            console.log('Country selected:', this.selectedCountryId);
        } else {
            this[fieldName] = event.target.value;
            console.log('Input changed:', fieldName, event.target.value);
        }
    }

    // Handle form submission
    handleSubmit() {
        console.log('Form submitted');
        console.log('Selected Certificate ID:', this.selectedCertificateId);
        console.log('Selected Module IDs:', this.selectedModuleIds);

        if (!this.selectedCertificateId) {
            console.error('Validation failed: Certificate not selected.');
            this.showToast('Error', 'Please select a certificate.', 'error');
            return;
        }

        if (this.selectedModuleIds.length === 0) {
            console.error('Validation failed: No modules selected.');
            this.showToast('Error', 'Please select at least one module.', 'error');
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
            invoiceEmail: this.invoiceEmail,
            selectedCountryId: this.selectedCountryId
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
                invoiceEmail: this.invoiceEmail,
                selectedCountryId: this.selectedCountryId
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
                console.error('Error creating case or sending email:', error);
                this.showToast('Error', 'Error creating case or sending email: ' + error.body.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // Reset form data
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
    }

    // Show toast messages
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