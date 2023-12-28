public with sharing class sendAccountsAsync implements Database.Batchable<sObject>, Database.AllowsCallouts{
    public final set<Id> accIds;
    public final set<Id> ordIds;
    public final set<Id> objectIds;
    public final string objectName;

    public sendAccountsAsync(set<id> accountIds, set<id> orderIds, String objName){
        accIds = accountIds;
        ordIds = orderIds;
        objectName = objName;

        if(objectName == 'Account') {
            objectIds = accIds;
        } else {
            objectIds = ordIds;
        }

        system.debug(accountIds);
        system.debug(orderIds);
        system.debug(objName);
    }

    public Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator('SELECT id FROM '+objectName+' WHERE Id in: objectIds');
    }

    public void execute(Database.BatchableContext BC, List<sObject> scope){
        for(sObject obj: scope) {

            if(objectName=='Account') {
                String resp = WeclappOutboundInIntegration.SendAccountToWeclapp(obj.id);
                if (resp != 'Success' && !test.isRunningTest()) {
                    throw new WeclappOutboundInIntegration.weclappIntegrationException(resp);
                }
            }

            if(objectName=='Order') {
                String resp = WeclappOutboundInIntegration.SendOrderToWeclapp(obj.id);
                if (resp != 'Success' && !test.isRunningTest()) {
                    throw new WeclappOutboundInIntegration.weclappIntegrationException(resp);
                }
            }
        }
    }

    public void finish(Database.BatchableContext BC){
        if(objectName=='Account') {
            Database.executeBatch(new sendAccountsAsync(new set<id>(),ordIds , 'Order'));
        }
    }
}