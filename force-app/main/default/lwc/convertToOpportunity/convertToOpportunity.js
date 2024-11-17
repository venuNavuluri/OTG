import { LightningElement, track, wire, api } from 'lwc';
import convertOpportunity from '@salesforce/apex/ConvertToOpportunityController.convertToOpportunity';
//import { getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import Account_Field from "@salesforce/schema/Lead.Account__c";
//import { CloseActionScreenEvent } from "lightning/actions";

const FIELDS = [Account_Field];

export default class ConvertToOpportunity extends LightningElement
{
    @track isConverting = false;
    @api recordId;

    /*@wire(getRecord, {recordId : "$recordId", fields : FIELDS})
    wiredRecord({error, data})
    {
        console.log('error --> ' + error);
        console.log('data --> ' + JSON.stringify(data));
        console.log('recordId --> ' + this.recordId);

        if (error)
        {
            this.dispatchEvent(
              new ShowToastEvent({
                title: "Error occured",
                message: "Unexpected Error occured, please contact Tech-Support Team",
                variant: "error",
              }),
            );
            this.dispatchEvent(new CloseActionScreenEvent());
        }
        else if (data)
        {
            this.recId = data.fields.id;
            convertOpportunity({
                recId : this.recordId
            }).then((result) => {
                
                console.log("result --> " + result);
                if(result != "Error" && result != "Exception")
                {
                    this.dispatchEvent(
                        new ShowToastEvent({
                          title: "Success",
                          message: "Opportunity got created and you will be navigated to it.",
                          variant: "success",
                        }),
                    );
                    window.location.href = "/" + result;
                }
                else if(result == 'Error')
                {
                    this.dispatchEvent(
                        new ShowToastEvent({
                          title: "Error occured",
                          message: "Lead Account or Contact is Empty. Please update Account or Contact fields with appropriate values.",
                          variant: "error",
                        }),
                    );
                }
                else if(result == 'Exception')
                {
                    this.dispatchEvent(
                        new ShowToastEvent({
                          title: "Error occured",
                          message: "Unexpected Error occured, please contact Tech-Support Team",
                          variant: "error",
                        }),
                    );
                }
            }).catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                      title: "Error occured",
                      message: "Unexpected Error occured, please contact Tech-Support Team",
                      variant: "error",
                    }),
                );
            });
            setTimeout(5000);
            this.dispatchEvent(new CloseActionScreenEvent());
        }
    }*/
    convertLead(event)
    {
        console.log('recId rend--> ' + this.recordId);
        this.isConverting = true;
        convertOpportunity({
            recId : this.recordId
        }).then((result) => {
            
            console.log("result --> " + result);
            if(result != "Error" && !result.includes("Error"))
            {
                this.dispatchEvent(
                    new ShowToastEvent({
                      title: "Success",
                      message: "Opportunity got created and you will be navigated to it.",
                      variant: "success",
                    }),
                );
                this.isConverting = false;
                window.location.href = "/" + result;
            }
            else if(result == 'Error')
            {
                this.dispatchEvent(
                    new ShowToastEvent({
                      title: "Error occured",
                      message: "Lead Account or Contact is Empty. Please update Account or Contact fields with appropriate values.",
                      variant: "error",
                    }),
                );
                this.isConverting = false;
            }
            else
            {
                this.dispatchEvent(
                    new ShowToastEvent({
                      title: "Error occured",
                      message: result,
                      variant: "error",
                    }),
                );
                this.isConverting = false;
            }
        }).catch(error => {
            this.dispatchEvent(
                new ShowToastEvent({
                  title: "Error occured",
                  message: "Unexpected Error occured, please contact Tech-Support Team",
                  variant: "error",
                }),
            );
            this.isConverting = false;
        });
    }
}