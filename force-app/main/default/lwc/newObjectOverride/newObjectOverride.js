import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';

import GetRecordTypeById from '@salesforce/apex/bg_NewObjectOverrideController.GetRecordTypeById';

export default class newObjectOverride extends NavigationMixin(LightningElement) {

    @api
    get objectInfo() {
        return this._objectInfo;
    }

    set objectInfo(value) {
        console.log(value);
       this._objectInfo = value;
       this.sObjectName = value.sObjectName;
       this.recordTypeId = value.recordTypeId;
       this.handleNewObject();
    }

    @track sObjectName;
    @track recordTypeId;
    @track showError = false;
    @track _objectInfo;


    handleNewObject(event) {
        this.showError = false;
        if (this.sObjectName) {
            GetRecordTypeById({ sObjectName : this.sObjectName, recordTypeId : this.recordTypeId })
            .then((result) => {
                if ((result.Name === 'Invoice Account' || result.Name === 'Replica Invoice Account') && result.SobjectType === 'Account') {
                    this.showError = true;
                    return;
                }

                this[NavigationMixin.Navigate]({
                    type: 'standard__objectPage',
                    attributes: {
                        objectApiName: this.sObjectName,
                        actionName: 'new'
                    },
                    state: {
                        nooverride: 1,
                        recordTypeId: this.recordTypeId
                    }
                });
            });
        }
    }
}