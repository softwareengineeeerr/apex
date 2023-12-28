public class ShipmentTriggerHandler {
    ShipmentTriggerHandlerHelper handlerHelper = new ShipmentTriggerHandlerHelper();
    
    public void beforeInsert(List<Shipment__c> shipments) {
        handlerHelper.adjustEstimatedDeliveryDate(null, shipments);
    }

    public void beforeUpdate(Map<Id,Shipment__c> oldShipments, Map<Id,Shipment__c> newShipments) {
        handlerHelper.preventUpdateForCanceledShipments(oldShipments, newShipments);
        handlerHelper.adjustEstimatedDeliveryDate(oldShipments, newShipments.values());
    }
}