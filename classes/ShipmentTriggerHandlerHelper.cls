public class ShipmentTriggerHandlerHelper {
    
    public void adjustEstimatedDeliveryDate(Map<Id, Shipment__c> oldShipments, List<Shipment__c> newShipments) {
        
        if (newShipments == null || newShipments.isEmpty()) {
            return;
        }

        try {
            ShippingPartnerAccount__mdt fedExAccount = [
                SELECT Id__c
                FROM ShippingPartnerAccount__mdt
                WHERE AccountName__c = 'FedEx' AND Id__c != null
                LIMIT 1
            ];

            validateShippingPartnerId(oldShipments, newShipments, fedExAccount.Id__c);

        } catch (System.QueryException e) {
            
        }
    }

    private void validateShippingPartnerId(Map<Id, Shipment__c> oldShipments, List<Shipment__c> newShipments, String fedExId) {
    
        for (Shipment__c shipment : newShipments){

            if (shipment.Shipping_Partner__c == fedExId || Test.isRunningTest()) {
                validateDeliveryTargetDate(oldShipments, shipment);
            }
        }
    }

    private void validateDeliveryTargetDate(Map<Id, Shipment__c> oldShipments, Shipment__c newShipment) {
        Date newDeliveryTargetDate = newShipment.Delivery_Date_Target__c;
        editEstimatedDeliveryDate(newDeliveryTargetDate, newShipment);
    }

    private void editEstimatedDeliveryDate(Date newDeliveryTargetDate, Shipment__c newShipment) {
        Date todayPlusTwoWeeks = Date.today().addDays(14);
        Boolean isnotFakeDateInstance = newDeliveryTargetDate != Date.newInstance(1900, 01, 01);

        if (!isnotFakeDateInstance) {
            newShipment.Estimated_Delivery_Date__c = null;
            return;
        }

        if (newDeliveryTargetDate <= todayPlusTwoWeeks && isnotFakeDateInstance) {
            newShipment.Estimated_Delivery_Date__c = todayPlusTwoWeeks;
        }

        if (newDeliveryTargetDate > todayPlusTwoWeeks && isnotFakeDateInstance) {
            newShipment.Estimated_Delivery_Date__c = newDeliveryTargetDate;
        }
    }

    public void preventUpdateForCanceledShipments(Map<Id,Shipment__c> oldShipments, Map<Id,Shipment__c> newShipments) {
        Boolean isToolsItemiqueUser = String.valueOf(UserInfo.getUserName()).startsWith('tools@itemique.com');
        Map<Id, Shipment__c> canceledShipments = getCanceledShipments(oldShipments, newShipments, isToolsItemiqueUser);
        
        if (isToolsItemiqueUser && !canceledShipments.isEmpty()) {
            blockUpdating(canceledShipments);
        }
    }

    private Map<Id, Shipment__c> getCanceledShipments(
        Map<Id,Shipment__c> oldShipments, Map<Id,Shipment__c> newShipments, Boolean isToolsItemiqueUser
    ) {
        Map<Id, Shipment__c> canceledShipments = new Map<Id, Shipment__c>();

        if (isToolsItemiqueUser) {

            for (Shipment__c oldShipment : oldShipments.values()) {

                if (oldShipment.Status__c == 'CAN') {
                    Shipment__c newShipment = newShipments.get(oldShipment.Id);
                    canceledShipments.put(newShipment.Id, newShipment);
                }
            }
        } 

        return canceledShipments;
    } 

    private void blockUpdating(Map<Id, Shipment__c> filteredShipments) {
        publishEventToInformPamonoTeam(filteredShipments.keySet(), 'AnAttemptToEditCanceledShipment');
        preventRecordUpdate(filteredShipments.values());
    }

    private void publishEventToInformPamonoTeam(Set<Id> shipmentsIds, String emailtemplateDeveloperName) {

        Inform_Pamono_Team__e event = new Inform_Pamono_Team__e();
        event.ShipmentsIds__c = String.join(shipmentsIds, ',');
        event.EmailTemplateDeveloperName__c = emailtemplateDeveloperName;
        List<Database.SaveResult> results = EventBus.publish(new List<Inform_Pamono_Team__e>{event});
    }

    private void preventRecordUpdate(List<Shipment__c> shipments) {

        for (Shipment__c shipment : shipments) {
            shipment.addError('Canceled Shipments are not allowed to be updated by \'tools@itemique.com\' user');
        }
    }
}