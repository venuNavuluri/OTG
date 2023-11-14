import { LightningElement,api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class ManageInstallationsLauncher extends NavigationMixin(LightningElement) {

    @api recordId

    connectedCallback(){
        this.handleNavigate()
    }

    handleNavigate(){
        this[NavigationMixin.GenerateUrl]({
            type: "standard__navItemPage",
            attributes: {
                apiName :"Manage_Installations"
            }
        }).then(url => {
            sessionStorage.removeItem("quoteRecId")
            sessionStorage.setItem("quoteRecId",this.recordId)
            this.dispatchEvent(new CustomEvent('lightning__actionsclosesscreen',{bubbles:true,composed:true}))
            window.open(url, "_blank");
        });
    }
}