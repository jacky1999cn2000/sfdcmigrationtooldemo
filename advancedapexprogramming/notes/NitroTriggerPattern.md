# Chapter 6 (P.S. NitroTriggerPattern)

### 每个trigger里面都调用NitroTriggerDispatcher.TriggerDispatcher():
```javascript
  trigger nitroAccountEATrigger on Account (after insert, after update) {

  	Nitro_Configuration__c configData = Nitro_Configuration__c.getInstance(NitroConstants.NITRO_CUSTOM_SETTING_NAME);

  	if(configData == null){
  		return;
  	}

  	if(configData.EA_Account_Trigger__c){
  	  if(Trigger.IsInsert) {
  	        NitroTriggerDispatcher.TriggerDispatcher(Trigger.newMap, Trigger.oldMap, 'Account', 'Insert');
  	    }
  	  if(Trigger.IsUpdate) {
  	        NitroTriggerDispatcher.TriggerDispatcher(Trigger.newMap, Trigger.oldMap, 'Account', 'Update');
  	    }
  	}
  	else{
  		return;
  	}
  }
```

### NitroTriggerDispatcher决定了哪个class来handle哪种trigger,之所以能够动态决定,归功于两件事:
  * `nitroEATriggerHandlerManager.newClassInstance()`方法可以根据名字动态的创建一个class的instance
  * 所有的handler class都implement了`NitroEATriggerHandlerFactory.IEATHFactory interface`,从而可以看做是同一类型的class,因为该`interface`中定义了`triggerHandler`函数,所以可以直接调用
```javascript
global class NitroTriggerDispatcher {

  global static void TriggerDispatcher(Map<Id,sObject> newMap, Map<Id,sObject> oldMap, String triggerObject, String triggerType){

    NitroEATriggerHandlerManager nitroEATriggerHandlerManager = new NitroEATriggerHandlerManager();

    if(triggerObject.contains('__c')){
    	nitroEATriggerHandlerManager.newClassInstance('NitroCustomObjectEATH').triggerHandler(newMap,oldMap,triggerObject,triggerType);
    }else{
		nitroEATriggerHandlerManager.newClassInstance('Nitro' + triggerObject + 'EATH').triggerHandler(newMap,oldMap,triggerObject,triggerType);
    }

  }

}
```

### nitroEATriggerHandlerManager:
```javascript
public with sharing class NitroEATriggerHandlerManager {
  public NitroEATriggerHandlerManager(){}

    // Return the appropriate class instance based on className
    public NitroEATriggerHandlerFactory.IEATHFactory newClassInstance(String className)
    {
        Type t = Type.forName(className);
        return (NitroEATriggerHandlerFactory.IEATHFactory) t.newInstance();
    }

}
```

### 这是一个handler class的例子
```javascript
public with sharing class NitroCustomObjectEATH extends NitroEATriggerHandlerFactory.EATHFactoryBase implements NitroEATriggerHandlerFactory.IEATHFactory {

  ...

  public void triggerHandler(Map<Id,sObject> newMap,Map<Id,sObject> oldMap,String objectName,String triggerType){

      ...

      if(!isThereActivities(objectName,triggerType)){
          return;
      }

      ...

      if(triggerType == 'Insert'){
        InsertHandler(newMap);
      }else{
        UpdateHandler(newMap,oldMap);
      }       
  }

  private void InsertHandler(Map<Id,sObject> newMap){
    ...
  }
  private void UpdateHandler(Map<Id,sObject> newMap){
    ...
  }
}
```

### 这是基类:
```javascript
public with sharing class NitroEATriggerHandlerFactory {
  	// Class Factory template
    public interface IEATHFactory{
       void triggerHandler(Map<Id,sObject> newMap,Map<Id,sObject> oldMap,String objectName,String triggerType);
    }

    // Class Factory base class
    public virtual class EATHFactoryBase {

        ...

        public Boolean isThereActivities(String objectName,String triggerType){
          ...
        }

        ...

        //所有其他公用的方法都写在这里
    }

}
```
