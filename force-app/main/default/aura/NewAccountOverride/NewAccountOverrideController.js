({
    doInit : function(component) {
        console.log('init');
        const recordTypeId = component.get("v.pageReference").state.recordTypeId;
        component.set("v.recordTypeId", recordTypeId);

        const objectToggle = component.get("v.newObjectToggle");
        component.set("v.newObjectToggle", !objectToggle);

        const objectInfo = {
            recordTypeId: recordTypeId,
            sObjectName: 'Account',
            objectToggle: !objectToggle
        }

        component.set("v.objectInfo", objectInfo);
    }
})