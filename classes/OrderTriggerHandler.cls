public with sharing class OrderTriggerHandler {

    private static OrderService orderService;

    static {
        if (orderService == null) {
            orderService = new OrderService();
        }
    }


    public static void configurePartialInvoices(List<Order> orders) {
        List<Order> partialInvoices = fetchPartialInvoices(orders);

        if (partialInvoices.isEmpty()) {
            return;
        }

        Map<Id, Order> parentInvoices = new Map<Id, Order> (
            new OrderSelector().getOrdersByIds( fetchParentInvoiceIds(partialInvoices) )
        );

        Id partialInvoiceRTId = RecordTypeUtils.getRecordTypeByDeveloperName(Order.getSObjectType(), 'Partial_Invoice');

        PartialInvoicingSettings__c settings = PartialInvoicingSettings__c.getInstance();
        Map<Id, Cost_Center__c> costCenters = new OrderSelector().getCostCentersByIds(
            new Set<Id> { settings?.DefaultInterimCostCenterId__c }
        );

        for (Order partialInvoice : partialInvoices) {
            Order relatedParentInvoice = parentInvoices.get(partialInvoice.Parent_Invoice__c);
            
            if (relatedParentInvoice != null) {
                partialInvoice = copyParentFields(partialInvoice, relatedParentInvoice);
            }

            Boolean isInterimInvoice = (partialInvoice.Partial_Invoice_Type__c == 'AR');

            if (isInterimInvoice) {
                partialInvoice.Cost_Center__c = costCenters.get(settings?.DefaultInterimCostCenterId__c)?.Id;
            }

            partialInvoice.RecordTypeId = partialInvoiceRTId;
        }
    }

    private static List<Order> fetchPartialInvoices(List<Order> orders) {
        List<Order> partialInvoices = new List<Order>();

        for (Order order : orders) {
            if (String.isBlank(order.Parent_Invoice__c)) {
                continue;
            }

            partialInvoices.add(order);
        }

        return partialInvoices;
    }

    private static Set<Id> fetchParentInvoiceIds(List<Order> partialInvoices) {
        Set<Id> parentInvoiceIds = new Set<Id>();

        for (Order partialInvoice : partialInvoices) {
            parentInvoiceIds.add(partialInvoice.Parent_Invoice__c);
        }

        return parentInvoiceIds;
    }

    private static Order copyParentFields(Order partialInvoice, Order parentInvoice) {
        Set<String> fieldsToCopy = new Set<String> {
            'PoNumber', 'Project__c', 'MonthPeriod__c', 'PaymentTerms__c', 'ConsultingGroup__c',
            'Cost_Center__c', 'Sales_Tax_Rule__c'
        };

        for (String field : fieldsToCopy) {
            partialInvoice.put(field, parentInvoice.get(field));
        }

        return partialInvoice;
    }

    
    public static void configureDocumentsSharing(List<Order> actualOrders, Map<Id, Order> oldOrders) {
        List<Order> affectedOrders = new List<Order>();

        affectedOrders.addAll(
            fetchOrdersByGeneratedField(actualOrders, oldOrders, 'Sync_Status__c')
        );

        affectedOrders.addAll(
            fetchOrdersByGeneratedField(actualOrders, oldOrders, 'Order_Sync_Status__c')
        );

        affectedOrders.addAll(
            fetchOrdersByGeneratedField(actualOrders, oldOrders, 'InvoiceCancellation_Sync_Status__c')
        );

        if (!affectedOrders.isEmpty()) {
            orderService.configureContentDocumentsCommunitySharing(new Map<Id, Order> (affectedOrders).keySet());
        }
    }


    public static void attachGeneratedDocumentsToRelatedRecords(List<Order> actualOrders, Map<Id, Order> oldOrders) {
        List<Order> affectedOrders = new List<Order>();

        affectedOrders.addAll(
            fetchOrdersByGeneratedField(actualOrders, oldOrders, 'Sync_Status__c')
        );

        affectedOrders.addAll(
            fetchOrdersByGeneratedField(actualOrders, oldOrders, 'Order_Sync_Status__c')
        );

        affectedOrders.addAll(
            fetchOrdersByGeneratedField(actualOrders, oldOrders, 'InvoiceCancellation_Sync_Status__c')
        );

        if (!affectedOrders.isEmpty()) {
            List<ContentDocumentLink> attachedDocumentLinks = buildContentDocumentLinks(
                new OrderSelector().getOrdersWithDocumentsByIds(new Map<Id, Order>(affectedOrders).keySet())
            );

            if (!attachedDocumentLinks.isEmpty()) {
                insert attachedDocumentLinks;
            }
        }
    }


    public static void configureRelatedMonthPeriods(List<Order> actualOrders, Map<Id, Order> oldOrders) {
        List<Order> generatedOrders = fetchOrdersByGeneratedField(
            actualOrders, 
            oldOrders, 
            'Sync_Status__c'
        );

        List<Order> generatedCreditNotes = fetchOrdersByRecordType(
            generatedOrders,
            RecordTypeUtils.getRecordTypeByDeveloperName(Order.getSObjectType(), 'Credit_Note')
        );

        Set<Id> monthPeriodIds = fetchMonthPeriodIds(generatedCreditNotes);

        if (!monthPeriodIds.isEmpty()) {
            orderService.configureRelatedMonthPeriods(monthPeriodIds);
        }
    }


    private static List<Order> fetchOrdersByGeneratedField(
        List<Order> actualOrders, 
        Map<Id, Order> oldOrders,
        String fieldName
    ) {
        List<Order> generatedOrders = new List<Order>();

        for (Order actualOrder : actualOrders) {
            Order oldOrder = oldOrders.get(actualOrder.Id);
            
            if (oldOrder == null) {
                continue;
            }

            String currentSyncStatus = String.valueOf(actualOrder.get(fieldName));
            String previousSyncStatus = String.valueOf(oldOrder.get(fieldName));

            if (currentSyncStatus != previousSyncStatus && currentSyncStatus == 'Generated') {
                generatedOrders.add(actualOrder);
            }
        }

        return generatedOrders;
    }

    private static List<Order> fetchOrdersByRecordType(List<Order> orders, Id recordTypeId) {
        List<Order> affectedOrders = new List<Order>();

        for (Order order : orders) {
            if (order.RecordTypeId != recordTypeId) {
                continue;
            }

            affectedOrders.add(order);
        }

        return affectedOrders;
    }

    private static List<ContentDocumentLink> buildContentDocumentLinks(List<Order> orders) {
        List<ContentDocumentLink> documentLinks = new List<ContentDocumentLink>();

        for (Order order : orders) {
            if (order.ContentDocumentLinks.isEmpty()) {
                continue;
            }
            
            Set<String> fieldsToCheck = new Set<String> { 'MonthPeriod__c', 'Project__c', 'Project_AB__c' };
            Id contentDocumentId = order.ContentDocumentLinks[0].ContentDocumentId;

            for (String field : fieldsToCheck) {
                if (order.get(field) != null) {
                    documentLinks.add(
                        buildContentDocumentLink(String.valueOf(order.get(field)), contentDocumentId)
                    );
                }
            }
        }

        return documentLinks;
    }

    private static ContentDocumentLink buildContentDocumentLink(Id parentId, Id contentDocumentId) {
        ContentDocumentLink documentLink = new ContentDocumentLink(
            LinkedEntityId = parentId,
            ContentDocumentId = contentDocumentId,
            Visibility = 'AllUsers'
        );

        return documentLink;
    }
    

    private static Set<Id> fetchMonthPeriodIds(List<Order> orders) {
        Set<Id> monthPeriodIds = new Set<Id>();

        for (Order order : orders) {
            if (order.MonthPeriod__c == null) {
                continue;
            }

            monthPeriodIds.add(order.MonthPeriod__c);
        }

        return monthPeriodIds;
    }


    public static void configureLockingState(List<Order> orders) {
        for (Order order : orders) {
            order.Locked__c = (order.Status != 'Draft');
        }
    }

    public static void configureLockingState(List<Order> actualOrders, Map<Id, Order> oldOrders) {
        List<Order> changedOrders = fetchOrdersByChangedFields(
            actualOrders,
            oldOrders,
            new Set<String> {'Status'}
        );

        for (Order order : changedOrders) {
            order.Locked__c = (order.Status != 'Draft');
        }
    }


    public static void configureSalesTaxRule(List<Order> orders) {
        SalesTaxConfigurator configurator = new SalesTaxConfigurator('Order', 'OrderItem');

        configurator.configureParents(orders);
    }

    public static void configureSalesTaxRule(List<Order> actualOrders, Map<Id, Order> oldOrders) {
        List<Order> changedOrders = fetchOrdersByChangedFields(
            actualOrders,
            oldOrders,
            new Set<String> {'BillingCountryCode'}
        );

        if (!changedOrders.isEmpty()) {
            SalesTaxConfigurator configurator = new SalesTaxConfigurator('Order', 'OrderItem');

            configurator.configureParents(changedOrders);
        }
    }


    public static void calculateGeneratedInvoiceAmount(List<Order> actualOrders, Map<Id, Order> oldOrders) {
        List<Order> changedOrders = fetchOrdersByChangedFields(
            actualOrders,
            oldOrders,
            new Set<String> {'Status', 'GeneratedPartialInvoicesAmount__c', 'Total_Amount__c'}
        );

        if (!changedOrders.isEmpty()) {
            List<Order> calculatedOrders = orderService.calculateCorrectGeneratedInvoiceAmount(changedOrders);

            update calculatedOrders;
        }
    }


    private static List<Order> fetchOrdersByChangedFields(
        List<Order> actualOrders,
        Map<Id, Order> oldOrders,
        Set<String> fieldNames
    ) {
        List<Order> changedOrders = new List<Order>();

        for (Order actualOrder : actualOrders) {
            Order oldOrder = oldOrders.get(actualOrder.Id);

            if (oldOrder == null) {
                continue;
            }

            for (String fieldName : fieldNames) {
                if (actualOrder.get(fieldName) != oldOrder.get(fieldName)) {
                    changedOrders.add(actualOrder);
                    break;
                }
            }
        }

        return changedOrders;
    }

}