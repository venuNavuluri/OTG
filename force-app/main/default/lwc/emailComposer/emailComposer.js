import { LightningElement, api, wire, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

import getSupportEmailTemplate from '@salesforce/apex/EmailComposerController.getSupportEmailTemplate';
import renderEmailTemplate from '@salesforce/apex/EmailComposerController.renderEmailTemplate';
import sendEmailAndUpdateLead from '@salesforce/apex/EmailComposerController.sendEmailAndUpdateLead';
import getOrgWideEmails from '@salesforce/apex/EmailComposerController.getOrgWideEmails';

const LEAD_FIELDS = ['Lead.Email', 'Lead.FirstName', 'Lead.LastName', 'Lead.Status'];

export default class EmailComposer extends LightningElement {
    @api recordId;

    recipientEmail = '';
    emailSubject = '';
    emailBody = '';

    fromEmail = '';
    ccEmails = '';
    bccEmails = '';

    orgWideEmails = [];

    isLoading = false;
    isSending = false;
    supportTemplateId = '';

    @wire(getRecord, { recordId: '$recordId', fields: LEAD_FIELDS })
    wiredLead({ error, data }) {
        if (data) {
            this.recipientEmail = data.fields.Email.value;
            this.loadSupportTemplate();
        } else if (error) {
            this.showError('Error loading lead data', error.body.message);
        }
    }

    connectedCallback() {
        this.loadOrgWideEmails();
    }

    loadSupportTemplate() {
        this.isLoading = true;
        getSupportEmailTemplate()
            .then(templateId => {
                this.supportTemplateId = templateId;
                if (this.supportTemplateId) {
                    this.renderTemplate();
                } else {
                    this.showError('Error', 'Support Email Template not found');
                    this.isLoading = false;
                }
            })
            .catch(error => {
                this.showError('Error loading template', error.body.message);
                this.isLoading = false;
            });
    }

    renderTemplate() {
        renderEmailTemplate({
            templateId: this.supportTemplateId,
            leadId: this.recordId
        })
        .then(result => {
            this.emailSubject = result.subject;
            this.emailBody = result.body;

            // Inject body into div manually
            const bodyContainer = this.template.querySelector('[data-id="emailBody"]');
            if (bodyContainer) {
                bodyContainer.innerText = this.emailBody;
                bodyContainer.style.height = 'auto';
                bodyContainer.style.height = bodyContainer.scrollHeight + 'px';
            }
        })
        .catch(error => {
            this.showError('Error rendering template', error.body.message);
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    loadOrgWideEmails() {
        getOrgWideEmails()
            .then(data => {
                this.orgWideEmails = data;
                if (this.orgWideEmails.length > 0) {
                    this.fromEmail = this.orgWideEmails[0];
                }
            })
            .catch(error => {
                this.showError('Error loading org-wide emails', error.body.message);
            });
    }

    handleFromChange(event) {
        this.fromEmail = event.target.value;
    }

    handleCcChange(event) {
        this.ccEmails = event.target.value;
    }

    handleBccChange(event) {
        this.bccEmails = event.target.value;
    }

    handleSend() {
        if (!this.isFormValid) return;

        this.isSending = true;
        sendEmailAndUpdateLead({
            leadId: this.recordId,
            templateId: this.supportTemplateId,
            email: this.recipientEmail,
            fromEmail: this.fromEmail,
            cc: this.ccEmails,
            bcc: this.bccEmails,
            subject: this.emailSubject,
            body: this.emailBody
        })
        .then(() => {
            this.showSuccess('Email sent successfully and lead status updated');
            this.closeAction();
        })
        .catch(error => {
            this.showError('Error sending email', error.body.message);
        })
        .finally(() => {
            this.isSending = false;
        });
    }

    handleCancel() {
        this.closeAction();
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showSuccess(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: message,
            variant: 'success'
        }));
    }

    showError(title, message) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: 'error'
        }));
    }

    get isFormValid() {
        return this.supportTemplateId && this.recipientEmail && this.fromEmail && !this.isLoading && !this.isSending;
    }
}