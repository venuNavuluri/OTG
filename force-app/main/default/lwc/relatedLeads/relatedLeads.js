import { LightningElement, api, wire } from 'lwc';
import getRelatedLeads from '@salesforce/apex/RelatedLeadsController.getRelatedLeads';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader'; // Import loadStyle
import WrappedHeaderTable from '@salesforce/resourceUrl/WrappedHeaderTable'; // Import the static resource

export default class RelatedLeads extends NavigationMixin(LightningElement) {
    @api recordId;
    leads;
    error;
    stylesLoaded = false; // To ensure styles are loaded only once

    @wire(getRelatedLeads, { recordId: '$recordId' })
    wiredLeads({ error, data }) {
        if (data) {
            this.leads = data;
            console.log('Leads:', this.leads); // Log the data for debugging
        } else if (error) {
            this.error = error;
            console.error('Error:', error);
        }
    }

    // Getter for columns
    get columns() {
        return [
            { label: 'Lead Id', fieldName: 'Lead_ID__c' },
            { label: 'Lead Name', fieldName: 'leadLink', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_blank' }, wrapText: true },
            { label: 'Status', fieldName: 'Status' },
            { label: 'Is Converted', fieldName: 'IsConverted', type: 'boolean' },
            { label: 'Converted Date', fieldName: 'ConvertedDate', type: 'date', wrapText: true },
            { label: 'Lead Source', fieldName: 'LeadSource', wrapText: true },
            { label: 'Products', fieldName: 'Products__c', wrapText: true },
            { label: 'Lead Progress Comments', fieldName: 'Lead_Progress_Comments__c', wrapText: true },
            { label: 'Description', fieldName: 'Description', wrapText: true }
        ];
    }

    // Getter to add link to leads
    get leadsWithLinks() {
        return this.leads.map(lead => {
            return {
                ...lead,
                leadLink: `/${lead.Id}` // Create the URL for the Lead Name
            };
        });
    }

    // Loading styles in renderedCallback
    renderedCallback() {
        if (!this.stylesLoaded) {
            Promise.all([loadStyle(this, WrappedHeaderTable)])
                .then(() => {
                    console.log('Custom styles loaded');
                    this.stylesLoaded = true; // Ensure styles are only loaded once
                })
                .catch((error) => {
                    console.error('Error loading custom styles:', error);
                });
        }
    }
}