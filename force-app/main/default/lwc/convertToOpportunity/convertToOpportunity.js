import { LightningElement, track, wire, api } from 'lwc';
import convertOpportunity from '@salesforce/apex/ConvertToOpportunityController.convertToOpportunity';
//import { getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import Account_Field from "@salesforce/schema/Lead.Account__c";
//import { CloseActionScreenEvent } from "lightning/actions";

import getActivatedContracts from '@salesforce/apex/ConvertToOpportunityController.getActivatedContracts';
import updateOpportunityWithContract from '@salesforce/apex/ConvertToOpportunityController.updateOpportunityWithContract';
const FIELDS = [Account_Field];

export default class ConvertToOpportunity extends LightningElement
{
    @track isConverting = false;
    @api recordId;

    @track showContractSelection = false;
    @track contracts = [];
    @track selectedContractId;
    opportunityId;

    convertLead(event) {
        console.log('recId rend--> ' + this.recordId);
        this.isConverting = true;
        convertOpportunity({
            recId: this.recordId
        }).then((result) => {
            console.log("result --> " + result);
            if(result != "Error" && !result.includes("Error")) {
                this.opportunityId = result;
                this.checkForUpSellOpportunity();
            } else if(result == 'Error') {
                this.showError("Lead Account or Contact is Empty. Please update Account or Contact fields with appropriate values.");
            } else {
                this.showError(result);
            }
        }).catch(error => {
            this.showError("Unexpected Error occurred, please contact Tech-Support Team");
        });
    }

    checkForUpSellOpportunity() {
        getActivatedContracts({
            opportunityId: this.opportunityId
        }).then(result => {
            if (result && result.length > 0) {
                    this.contractOptions = result.map(contract => ({
                            label: contract.Contract_Flow_Label__c,
                            value: contract.Id
                        }));
                    this.showContractSelection = true;
                    this.isConverting = false;
            } else {
                this.navigateToOpportunity();
            }
        }).catch(error => {
            this.showError("Error checking for contracts: " + error.body.message);
        });
    }

    handleContractSelection(event) {
        this.selectedContractId = event.detail.value;
    }

    handleSubmit() {
        if (!this.selectedContractId) {
            this.showError("Please select a contract to proceed");
            return;
        }

        this.isConverting = true;
        updateOpportunityWithContract({
            opportunityId: this.opportunityId,
            contractId: this.selectedContractId
        }).then(() => {
            this.navigateToOpportunity();
        }).catch(error => {
            this.showError("Error updating opportunity: " + error.body.message);
        });
    }

    handleCancel() {
        this.navigateToOpportunity();
    }

    navigateToOpportunity() {
        this.dispatchEvent(
            new ShowToastEvent({
                title: "Success",
                message: "Opportunity was successfully created.",
                variant: "success",
            }),
        );
        window.location.href = "/" + this.opportunityId;
    }

    showError(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: "Error occurred",
                message: message,
                variant: "error",
            }),
        );
        this.isConverting = false;
    }
}