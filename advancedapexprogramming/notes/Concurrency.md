# Chapter 8 Concurrency

### 两个Exceptions
* EXCEPTION_THROWN SYSTEM.QueryException: Record Currently Unavailable: The record you are attempting to edit, or one of its related records, is currently being modified by another user. Please try again.

* FATAL_ERROR System.DmlException: Update failed. first error: UNABLE_TO_LOCK_ROW, unable to obtain exclusive access to this record.

### Apex中的concurrency
Apex作为一个语言是单线程的,不能创建新的thread.
Apex里面的static variable就相当于其他multithreading语言当中的thread local storage - data that are specific to one thread and one execution context.

然而,Force.com asynchronous processes do run in separate threads and can be concurrent. And these processes can access the database. So concurrency issues can occur - especially on high traffic system, or systems that support many asynchronous processes or incoming service calls.

### optimistic concurrency
在默认情况下，Salesforce默认optimistic concurrency,即假设concurrency issue不会发生,然后希望系统本身来处理concurrency问题,比如 - 如果两个用户同时在update一个record,那么第一个用户update时Salesforce会锁定这个record,而第二个用户会看到`Record Currently Unavailable: The record you are attempting to edit, or one of its related records, is currently being modified by another user. Please try again`错误.

但系统本身的处理能力是有限的,比如 it only applies to different users, if you have two asynchronous or external calls running in the same user context, and a concurrency issue comes up, it will typically not be detected.

### Pessimistic Record Locking (For Update)
如果想要你的execution context单独占有某个record,可以使用Pessimistic record locking. This is implemented by adding the "For Update" term to your SOQL query.

当你通过"for update" query锁定了某个record,其他试图读取这个record的threads会等到当前thread的execution context结束才能读取并继续进行下去. 如果当前线程占用时间太长超过了10秒,那么其他被blocked的线程则会time out,那个"UNABLE_TO_LOCK_ROW"错误会出现.

事实上,这个"UNABLE_TO_LOCK_ROW"的错误不仅仅在某个线程把一个record占有太长时间的情况下出现.假设很多用户同时通过UI来修改某个account,而这个account上有很多关联的contacts或者opportunity等等.这个account在每次修改时都会被锁定,加入修改account需要计算所有sharing rule,那会花很长时间,那么其他线程在试图修改这个account或者它的关联contacts(是的,关联的这些objects也都被锁定了)时很可能出现time out.

Apex locks records in two ways:
* First, it locks a record when you use "For Update" in a query;
* Second, it locks a record when you update it(the reason is if Apex code terminates with an exception, the system reverts the entire transaction. If the platform did not lock the records, other processes could modify those records and the revert operation would cause those changes to be lost without notice or warning. This lock held until the execution context ends)

避免出现concurrency error的两个原则:
* Avoid data skew (像上面那个account例子一样,没有频繁的read & update,发生concurrency的几率就小)
* Defer DML updates until near the end of the execution context

### Handling DML lock errors

###### synchronous operation
如果是synchronous operation比如trigger or UI operation, the answer is simple - don't handle them at all. Lock errors will be raised and the DML operations will return an error result. If it's a user operation, the user will see an error message inviting them to try again later. Any other changes made during the operation will revert and no harm will be done.

###### asynchronous operation

首先先来试图reproduce DML lock error
```javascript
public static void delay(Integer seconds)
{
    List<Integer> largeArray = new List<Integer>();
    for(Integer x =0; x<10000; x++) largeArray.add(x);
    for(Integer counter = 0; counter<seconds * 4; counter++)
    {
        String s = json.serialize(largeArray);
    }
}

// Create this opportunity by hand
private static String opportunityName = 'Concurrency1';

@future
public static void incrementOptimistic(double amount, Integer delayBefore, Integer delayFromQuery, Integer delayAfter){
    if(delayBefore>0) delay(delayBefore);
    List<Opportunity> ops = [Select ID, Amount From Opportunity where Name = :opportunityName];
    for(Opportunity op: ops)
      op.Amount = (op.Amount==null)? amount: op.Amount + Amount;
    if(delayFromQuery>0) delay(delayFromQuery);
    update ops;
    if(delayAfter>0) delay(delayAfter);
}

@future
public static void incrementPessimistic(double amount, Integer delayBefore, Integer delayFromQuery, Integer delayAfter){
    if(DelayBefore>0) delay(delayBefore);
    List<Opportunity> ops = [Select ID, Amount From Opportunity where Name = :opportunityName For Update];
    for(Opportunity op: ops)
      op.Amount = (op.Amount==null)? amount: op.Amount + Amount;
    if(delayFromQuery>0) delay(delayFromQuery);
    update ops;
    if(delayAfter>0) delay(delayAfter);
}
```
Both of these methods implement the following algorithm:
* Delay delayBefore seconds
* Query the opportunity record
* Delay delayFromQuery seconds
* Increment a field and update the opportunity record
* Delay delayAfter seconds

**optimistic concurrency**
先来reproduce concurrency error:

在anonymous Apex里面运行
```javascript
Concurrency1.incrementOptimistic( 10,0,2,0);
Concurrency1.incrementOptimistic( 10,1,0,0);
```
When you execute these commands, the two future calls will start running concurrently. The first one will query the value of the amount, wait two seconds, and update the record, adding 10 to the original amount. The second method will wait one second, query the record and update it immediately, adding 10 to the original amount. You may need to repeat this test to see the results, as there is no guarantee that both future operations will start at the same time.

Both of these methods increment the Amount by ten, so one would expect the end value to be 20. But the resulting value will be only ten. You’ve effectively reproduced a concurrency error by stretching out the time of the operations.

之所以能有concurrency error,是因为第一个future call在query之后停了2秒,这是record还未被锁定,这是第二个record开始query,读到的还是之前的数据,然后第二个future call进行update,系统锁定record,update完之后系统释放record,然后第一个future call继续进行update,但最终的record只加了10而不是20.

再来reproduce一个Lock error:
```javascript
Concurrency1.incrementOptimistic( 10,0,0,25);
Concurrency1. incrementOptimistic( 10,1,0,0);
```
The first method immediately adds 10 to the amount and updates the opportunity record. It then waits over 10 seconds before exiting (you may need to tinker with the value of the DelayAfter parameter – too short and it may not timeout, too long and you may see CPU timeout limits instead of DML lock errors).

The second method waits one second, then attempts to update the record. However, it is blocked by the first method. After about 10 seconds, the second method aborts with a DML lock (UNABLE_TO_LOCK_ROW) error.

由于第一个future call在update之后delay的时间过长,导致第二个future call读取record的时候time out.

**Pessimistic locing**
```javascript
Concurrency1.incrementPessimistic( 10,0,2,0);
Concurrency1.incrementPessimistic( 10,1,0,0);
```
This is the same scenario you saw earlier with the first optimistic locking example. But this time the amount field does increment to 20. That’s because the second method call is blocked and waits until the first one completes before it reads the record. The record thus contains the value as updated by the first method call.

But what if the first method takes too long to finish and the second method is blocked for too long? You can illustrate that scenario with the following code (again, you may need to tinker with the actual timeout value).
```javascript
Concurrency1.IncrementPessimistic( 10,0,20,0);
Concurrency1.IncrementPessimistic( 10,0,20,0);
```
One of the methods should fail with the following exception: System.QueryException: Record Currently Unavailable: The record you are attempting to edit, or one of its related records, is currently being modified by another user. Please try again.

### Reprocessing DML lock errors
When you run into a DML lock error in a synchronous operation, you may prefer to just let the error occur and allow the user or caller to handle the error. But if you want to handle these errors in an asynchronous operation, you have only two options – log the error, or try to recover from the error.

In either case, the first thing you have to do is capture the error. This is done by replacing the Update statement with the following code as illustrated in the incrementOptimisticWithCapture method:

```javascript
@future
public static void incrementOptimisticWithCapture(double amount, Integer delayBefore, Integer delayFromQuery, Integer delayAfter){
    if(delayBefore>0) delay(delayBefore);
    List<Opportunity> ops = [Select ID, Amount From Opportunity where Name = :opportunityName];
    for(Opportunity op: ops)
      op.Amount = (op.Amount==null)? amount: op.Amount + Amount;
    if(delayFromQuery>0) delay(delayFromQuery);
    List<Database.SaveResult> dmlResults = Database.Update(ops, false);
    List<Opportunity> failedUpdates = new List<Opportunity>();
    for(Integer x = 0; x< ops.size(); x++){
      Database.SaveResult sr = dmlResults[x];
      if(!sr.isSuccess()){
        for(Database.Error err: sr.getErrors()){
          if(err.getStatusCode() == StatusCode.UNABLE_TO_LOCK_ROW){
            failedUpdates.add(ops[x]);
            break;
          }
        }
      }
    }

    if(failedUpdates.size()>0){
      // Do a logging or recovery operation here
      recordRecoveryInformation(failedUpdates, amount);
    }

    if(delayAfter>0) delay(delayAfter);
}
```
The Database.Update statement has a parameter opt_allOrNone which can be set to false to indicate that the code should return an error result rather than throwing an exception. On return, the software tests each result to see if any failed. If the failure was due to a DML lock, the opportunity is stored in an array. We set the opt_allOrNone false because in a bulk update it’s very likely that the concurrency error would only apply to one or two records in the batch.

There are other types of DML errors that can occur here, so in a real application you might want to extend this code to detect and handle different errors. For example: while it might make sense to retry a DML failure due to a DML lock, you would likely want to log an error caused by a validation rule, as retrying it later is unlikely to work.

Things get more complex if you are updating related objects at the same time. In that case you may prefer to keep the opt_allOrNone field true and use the DML savepoint capability to wrap your DML operation inside of a transaction. But that’s an entirely different topic, and beyond the scope of this chapter.

Logging DML lock errors in this scenario is straightforward – just use a custom object to store any failure information that you wish to track. While the opportunity record may be locked, that won’t prevent you from inserting a new custom object. You’ll read more about diagnostic logging in chapter 9.

The interesting thing about a DML lock error is that it is recoverable. Even though this update timed out, one would expect that at some time in the future the update will succeed. So it’s quite reasonable to try again sometime in the future. Because you’re in a future or batch context already, you can’t just perform a future call. However, by remarkable coincidence, you already have a very nice asynchronous processing system that was implemented in chapter 7.

All it takes are a few simple changes to the AsyncRequest__c object:

* Add a currency field NewAmount__c
* Add a currency field OriginalAmount__c
* Add a lookup to an opportunity field TargetOpportunity__c
* Add picklist value “Amount Update” to the AsyncType__c field.

The recordRecoveryInformation method creates a new AsyncRequest__c object for each failed opportunity:

```javascript
@testvisible
private static void recordRecoveryInformation(
  List<Opportunity> failedOps, double amount)
{
  List<AsyncRequest__c> requests = new List<AsyncRequest__c>();
  for(Opportunity op: failedOps)
  {
    requests.add(new AsyncRequest__c(AsyncType__c = 'Amount Update',
      NewAmount__c = op.Amount,
      OriginalAmount__c = op.Amount - amount,
      TargetOpportunity__c = op.id ));
  }
  insert requests;
}
```
This method is called from the IncrementOptimisticWithCapture method as follows:
```javascript
if( failedUpdates.size() > 0) {
  // Do a logging or recovery operation here recordRecoveryInformation( failedUpdates, amount);
}
```
There’s a bit of a “cheat” here, where I determine the original value of the opportunity by subtracting the amount that was previously added. In a real application, you would likely keep an array of original values around in case you wanted to save them when failures occur. Why save the original value? You’ll see that shortly.

The GoingAsync.execute method needs to be modified to query the new AsyncRequest__c object fields:
```javascript
requests = [Select ID, AsyncType__c, Params__c, NewAmount__c, OriginalAmount__c, TargetOpportunity__c from AsyncRequest__c where Error__c = false And CreatedById = :UserInfo.getUserId() Limit 1 for update];
```
Now all that remains is to modify the execute statement to process the new type. First, add a branch call to a new updateAmounts function:
```javascript
try {
  if( currentRequest.AsyncType__c = =' Translate Solution')
    translate( currentRequest);
  if( currentRequest.AsyncType__c = =' Amount Update')
    updateAmounts( currentRequest);
    ...
  }
  ...
```
Next, define the updateAmounts function as follows:
```javascript
public void updateAmounts( AsyncRequest__c request){
  List < Opportunity > ops = [Select ID, Amount from Opportunity where ID = :request.TargetOpportunity__c for update]; if( ops.size() = = 0) return; // The op may have been deleted Opportunity op = ops[ 0];
  // Implement update scenarios here
}
```
Now comes the big question.

What fits into that block titled **“Implement update scenario here”**

Well, it depends. You could do a simple amount update like this:
```javascript
op.Amount = request.NewAmount__c;
```
But there’s a problem with this approach. What if somebody else has updated the opportunity amount in the meantime? In that case, you’re just trading a DML lock error for a concurrency error.

Another approach is to validate the current value of the opportunity against the original opportunity value – checking if some other process may have updated the amount.
```javascript
if( op.Amount! = request.OriginalAmount__c) {
  // Concurrency error - throw an exception here
  throw new AsyncUpdateException( 'Amount on opportunity update has changed');
}
```
What you are doing here is a very traditional form of optimistic locking – where you test to see if there is a concurrency issue before performing an update. In this case, if you see the value of the amount has changed, you can assume that there is a concurrency issue. You can then raise an exception, that tells the asynchronous framework to mark the AsyncRequest__c object as an error which can be analyzed later.

When it comes to updating the opportunity, as hard as it is to imagine, it’s still possible to run into yet another DML lock error. However, in this case it’s easy enough to handle – if you see a DML lock error, you can just clone the AsyncRequest__c object and insert the clone to request another try. That way, next time the async routine runs, your code will try the update again. Here’s one way you can implement this:

```javascript
try{
  update op;
}catch( DmlException dex) {
  if( dex.getDmlType( 0) = = StatusCode.UNABLE_TO_LOCK_ROW) {
    insert request.clone();
    return;
  }
  throw dex;
}
```
