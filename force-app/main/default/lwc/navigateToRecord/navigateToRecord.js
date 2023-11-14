import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
export default class NavigateToRecord extends NavigationMixin(LightningElement)
{

    @api recordToNavigateTo;
    @api sObjectType;
    @api newRecord;
    @api defaultFieldValues;
    @api recordTypeId;

    connectedCallback()
    {
        console.log(this.defaultFieldValues);
        console.log(this.recordTypeId);
        if (this.newRecord) {
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: this.sObjectType,
                    actionName: 'new'
                },
                state: {
                    defaultFieldValues : this.defaultFieldValues,
                    recordTypeId: this.recordTypeId,
                    nooverride: '1'
                }
            });
        } else {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.recordToNavigateTo,
                    object: this.sObjectType,
                    actionName: 'view'
                },
            });
        }
    }
}