trigger OrderTrigger on Order (before insert, before update, after update) {

    CustomTriggerSettings__c apexSwitcher = CustomTriggerSettings__c.getOrgDefaults();
    
    if(apexSwitcher.OrderTriggerEnabled__c) {

        if (RecursionBlocker.isFirstRun() == true) {
            RecursionBlocker.setFirstRunAsFalse();

            if (Trigger.isBefore) {
                if (Trigger.isInsert) {
                    OrderTriggerHandler.configureLockingState(Trigger.new);
                    OrderTriggerHandler.configureSalesTaxRule(Trigger.new);
                    OrderTriggerHandler.configurePartialInvoices(Trigger.new);
                }
        
                if (Trigger.isUpdate) {
                    OrderTriggerHandler.configureLockingState(Trigger.new, Trigger.oldMap);
                    OrderTriggerHandler.configureSalesTaxRule(Trigger.new, Trigger.oldMap);
                }
            }
        
            if (Trigger.isAfter) {
                OrderTriggerHandler.configureDocumentsSharing(Trigger.new, Trigger.oldMap);
                OrderTriggerHandler.attachGeneratedDocumentsToRelatedRecords(Trigger.new, Trigger.oldMap);
                OrderTriggerHandler.configureRelatedMonthPeriods(Trigger.new, Trigger.oldMap);
                OrderTriggerHandler.calculateGeneratedInvoiceAmount(Trigger.new, Trigger.oldMap);
            }
        }
    } 	
}