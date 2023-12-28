trigger ShipmentTrigger on Shipment__c (before insert, before update) {
    CustomTriggerSettings__c apexSwitcher = CustomTriggerSettings__c.getOrgDefaults();
    
    if(apexSwitcher.ShipmentTriggerEnabled__c) {

        if (RecursionBlocker.isFirstRun() == true) {
            RecursionBlocker.setFirstRunAsFalse();
            ShipmentTriggerHandler triggerHandler = new ShipmentTriggerHandler();

            if (Trigger.isBefore) { 

                if (Trigger.isInsert) {
                    triggerHandler.beforeInsert(Trigger.new);
                } 
                
                if (Trigger.isUpdate) {
                    triggerHandler.beforeUpdate(Trigger.oldMap, Trigger.newMap);
                }
            }
        }
    } 	
}