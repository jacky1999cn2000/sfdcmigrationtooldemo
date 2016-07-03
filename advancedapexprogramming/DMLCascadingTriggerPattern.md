# DML Cascading Trigger Pattern

Nitro中定义的trigger不会做DML操作,所以不会有 trigger1 -> trigger2 -> trigger3 这样的情况出现,那么如果

### trigger里都调用`TriggerArchitectureMain.entry()`方法
```javascript
trigger AccountTrigger on Account (after insert) {
  TriggerArchitectureMain.entry('Account', trigger.isBefore, trigger.isDelete, trigger.isAfter, trigger.isInsert, trigger.isUpdate, trigger.isExecuting, trigger.new, trigger.newMap, trigger.old,  trigger.oldMap);
}

trigger OpportunityTrigger on Opportunity (after update) {
  TriggerArchitectureMain.entry('Opportunity', trigger.isBefore, trigger.isDelete, trigger.isAfter, trigger.isInsert, trigger.isUpdate, trigger.isExecuting, trigger.new, trigger.newMap, trigger.old,  trigger.oldMap);
}
```

### TriggerArchitectureMain里做了这么几件事:
  * 定义了一个`ITriggerEntry interface` - 所有的handler都会implement这个interface,所以可以直接定义一个`activeFunction`变量来hold所有不同的handler class
  * `ITriggerEntry interface`包含2个方法(getName是我自己加的,没啥用)`mainEntry`和`inProgressEntry`
  * 当trigger被触发的时候,一个context execution就开始了,这时也仅仅这时TriggerArchitectureMain.activeFunction=null,接下来由于trigger里面做DML操作引发其他trigger,再进入TriggerArchitectureMain时,activeFunction都不再为null,原因就是static variable的生命周期为一个context execution
  * 当某个事件触发了某个trigger的时候,开始一个context execution,然后TriggerArchitectureMain根据trigger种类选择对应的handler class来处理trigger,如果在此期间发生了DML操作引发了其他trigger,这时TriggerArchitectureMain会把如何处理这些新trigger的决定权交给 **当前的handler class(via activeFunction.inProgressEntry())**,这是因为我们肯定这些新的trigger肯定是因为我们当前代码的DML操作而引起的(**因为在同一个context execution中 - 当然,这里面可能有别人的trigger,这个我门管不了,这个模式只关心自己trigger的重入问题**)
  * 比如这个例子里,我们知道我们在第一个OpportunityHandler中会insert Account,那么在OpportunityHandler.inProgressEntry()里面我们就加入了`	if(triggerObject == 'Account' && isAfter && isInsert)`的判断,然后进入该逻辑,给TriggerArchitectureMain.activeFunction重新赋值,继续运行

```javascript
public with sharing class TriggerArchitectureMain {

	public interface ITriggerEntry {
		String getName();

		void mainEntry(String triggerObject, Boolean isBefore, Boolean isDelete, Boolean isAfter,
									 Boolean isInsert, Boolean isUpdate, Boolean isExecuting, List<SObject> newList, Map<Id,SObject> newMap,
									 List<SObject> oldList, Map<Id,SObject> oldMap);

		void inProgressEntry(String triggerObject, Boolean isBefore, Boolean isDelete, Boolean isAfter,
									 Boolean isInsert, Boolean isUpdate, Boolean isExecuting, List<SObject> newList, Map<Id,SObject> newMap,
									 List<SObject> oldList, Map<Id,SObject> oldMap);
	}

	public static ITriggerEntry activeFunction = null;

	public static void entry(String triggerObject, Boolean isBefore, Boolean isDelete, Boolean isAfter, Boolean isInsert, Boolean isUpdate, Boolean isExecuting, List<SObject> newList, Map<Id,SObject> newMap,List<SObject> oldList, Map<Id,SObject> oldMap){

		if(activeFunction != null){
			System.debug('***activeFunction: ' + activeFunction.getName());
			activeFunction.inProgressEntry(triggerObject, isBefore, isDelete, isAfter, isInsert, isUpdate, isExecuting, newList, newMap, oldList,  oldMap);
			return;
		}

		if(triggerObject == 'Opportunity' && isAfter && isUpdate){
			activeFunction = new OpportunityHandler();
			activeFunction.mainEntry(triggerObject, isBefore, isDelete, isAfter, isInsert, isUpdate, isExecuting, newList, newMap, oldList,  oldMap);
			activeFunction = new OpportunityHandler2();
			activeFunction.mainEntry(triggerObject, isBefore, isDelete, isAfter, isInsert, isUpdate, isExecuting, newList, newMap, oldList,  oldMap);
		}

		if(triggerObject == 'Account' && isAfter && isUpdate){
			activeFunction = new AccountHanlder();
			activeFunction.mainEntry(triggerObject, isBefore, isDelete, isAfter, isInsert, isUpdate, isExecuting, newList, newMap, oldList,  oldMap);
		}
	}
}
```

# 根据下面handler classes的例子,当我们更新某个Opportunity的时候,代码运行的stack是:
```javascript
*** OpportunityHandler mainEntry Begin
*** Op:Insert|Type:Account|Rows:1
*** activeFunction: OpportunityHandler
*** OpportunityHandler inProgressEntry Begin

*** AccountHanlder mainEntry Begin
*** AccountHanlder mainEntry Exit

*** OpportunityHandler inProgressEntry Exit
*** OpportunityHandler mainEntry Exit
*** OpportunityHandler2 mainEntry Begin
*** OpportunityHandler2 mainEntry Exit
```

```javascript
///OpportunityHandler
public class OpportunityHandler implements TriggerArchitectureMain.ITriggerEntry {
	public String getName(){
		return 'OpportunityHandler';
	}

	public void mainEntry(String triggerObject, Boolean isBefore, Boolean isDelete, Boolean isAfter, Boolean isInsert, Boolean isUpdate, Boolean isExecuting, List<SObject> newList, Map<Id,SObject> newMap,List<SObject> oldList, Map<Id,SObject> oldMap){
		System.debug('*** OpportunityHandler mainEntry Begin');
		Account acct = new Account(Name='Test',BillingCity='San Francisco');
    insert acct;
		for(Integer i = 0; i < 10000; i++){

		}
		System.debug('*** OpportunityHandler mainEntry Exit');
	}

	public void inProgressEntry(String triggerObject, Boolean isBefore, Boolean isDelete, Boolean isAfter, Boolean isInsert, Boolean isUpdate, Boolean isExecuting, List<SObject> newList, Map<Id,SObject> newMap,List<SObject> oldList, Map<Id,SObject> oldMap){
		System.debug('*** OpportunityHandler inProgressEntry Begin');
		if(triggerObject == 'Account' && isAfter && isInsert){
			TriggerArchitectureMain.activeFunction = new AccountHanlder();
			TriggerArchitectureMain.activeFunction.mainEntry(triggerObject, isBefore, isDelete, isAfter, isInsert, isUpdate, isExecuting, newList, newMap, oldList,  oldMap);
		}
		System.debug('*** OpportunityHandler inProgressEntry Exit');
	}
}

///OpportunityHandler2
public class OpportunityHandler2 implements TriggerArchitectureMain.ITriggerEntry {
	public String getName(){
		return 'OpportunityHandler2';
	}

	public void mainEntry(String triggerObject, Boolean isBefore, Boolean isDelete, Boolean isAfter, Boolean isInsert, Boolean isUpdate, Boolean isExecuting, List<SObject> newList, Map<Id,SObject> newMap,List<SObject> oldList, Map<Id,SObject> oldMap){
		System.debug('*** OpportunityHandler2 mainEntry Begin');
		System.debug('*** OpportunityHandler2 mainEntry Exit');
	}

	public void inProgressEntry(String triggerObject, Boolean isBefore, Boolean isDelete, Boolean isAfter, Boolean isInsert, Boolean isUpdate, Boolean isExecuting, List<SObject> newList, Map<Id,SObject> newMap,List<SObject> oldList, Map<Id,SObject> oldMap){
		System.debug('*** OpportunityHandler2 inProgressEntry Begin');
		System.debug('*** OpportunityHandler2 inProgressEntry Exit');
	}
}

///OpportunityHandler2
public with sharing class AccountHanlder implements TriggerArchitectureMain.ITriggerEntry {
	public String getName(){
		return 'AccountHanlder';
	}

	public void mainEntry(String triggerObject, Boolean isBefore, Boolean isDelete, Boolean isAfter, Boolean isInsert, Boolean isUpdate, Boolean isExecuting, List<SObject> newList, Map<Id,SObject> newMap,List<SObject> oldList, Map<Id,SObject> oldMap){
		System.debug('*** AccountHanlder mainEntry Begin');
		System.debug('*** AccountHanlder mainEntry Exit');
	}

	public void inProgressEntry(String triggerObject, Boolean isBefore, Boolean isDelete, Boolean isAfter, Boolean isInsert, Boolean isUpdate, Boolean isExecuting, List<SObject> newList, Map<Id,SObject> newMap,List<SObject> oldList, Map<Id,SObject> oldMap){
		System.debug('*** AccountHanlder inProgressEntry Begin');
		System.debug('*** AccountHanlder inProgressEntry Exit');
	}
}

```
