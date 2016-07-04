# Chapter 7 Going Asynchronous

### Requirements
Consider a scenario where you are building a knowledge base using Solution objects, and wish to add a field that contains the machine translation of the solution details, say, to Spanish. You want to build an application that will automatically populate a new custom field, SolutionSpanish__c, on insertion or update of the Solution object. To perform the translation, you’ll use an external web service, such as Google Translate or Microsoft Translate.

### Set Stage
直接调用Google Translate service比较麻烦,所以写了一个SimulatedTranslator来模拟translate service,同时定义了一个实现了HttpCalloutMock接口的类用来返回模拟的Httprespons.
* [SimulatedTranslator](src/SimulatedTranslator.cls)
* [MockTranslator](src/MockTranslator.cls)

### Flawed Future Call
如果trigger里的batch达到200个solutions(trigger的default batch size)的话,则会出现`System.LimitException: Too many callouts: 101`的错误;因为firstAttempt()已经是future call,所以不能从其中再chain另一个future call来解决剩余未处理的sobjects;而且我们还没有考虑其他future call会失败的情况 - 比如服务器超时,down掉等等...

另外,还有可能有的时候对solutions的update操作就是在某个future call里进行的,这时当trigger被触发后,firstAttempt()会失败,因为无法在future call里调用另一个future call...

而且,所有未被处理的solutions的id都会被通通lost掉...

* [ClassCode](src/flawedfuturecall/ClassCode.cls)
* [TriggerCode](src/flawedfuturecall/TriggerCode.trigger)

### Industrial Robust Future Call

首先要有个方法来保存所有需要被处理的solutions的id,为此,我们在Solution object上添加一个custom field - TranslationPending__c; 我们使用了before trigger,因为这样可以便于操作TranslationPending__c.

handleTrigger()方法和上面的类似,只不过在最后没有直接call future,而是call一个叫做secondAttemptRequestAsync()的方法;

上面解决方案中的一个future method被替换成了3个新的方法:
  * secondAttemptRequestAsync() - 来判断是否做future call
  * secondAttemptSync() - 一个sync方法来做真正的weight lifting
  * secondAttemptAsync() - 一个future call,在里面call secondAttemptSync()

secondAttemptRequestAsync()方法先判断你是否已经在future或者batch的mode下:
  * 如果是,则直接call secondAttemptSync()方法;这是可行的 - 在future or batch mode里,你不能call another future call, 但是可以make callouts(需要@future(callout=true),这个在secondAttemptSync()中会做判断)
  * 如果不是,则看是否可以make future call(代码中还留了一些Limits余量给其他的code),如果可以的话,make future call,如果不可以的话,则退出 - 没关系,因为TranslationPending__c已经被标记为true,所以即便当下不能make future call,信息并未丢失,下次trigger被触发时会被处理

secondAttemptSync()是真正做具体处理的方法:
  * 首先检查一下是否可以做callout - 有可能不能做,比如secondAttemptRequestAsync()中本来就处于future mode里,而这个originating future call不支持callout(没有标记(callout=true))
  * 如果可以make callouts,则做query,query出和callout数量一样的solutions进行处理
    * LastModifiedDate是一个indexed field,在query时使用indexed field来make query selective is a good practice
    * 通过LastModifiedDate把query限制在过去24小时内是因为一旦某些solutions由于各种原因make callout失败,系统不会反复的query回这些solutions然后陷入limbo

这个方法最大的两个弊端:
  * 每次能处理的solutions数量还是很少(`Integer allowedCallouts = Limits.getLimitCallouts() - Limits.getCallouts();`)
  * there is no mechanism for the future call to restart itself(to invoke another future call in order to continue the processing)

* [ClassCode](src/industrialrobustfuturecall/ClassCode.cls)
* [TriggerCode](src/industrialrobustfuturecall/TriggerCode.trigger)

### Batch

上面的两个方法都遇到两个问题:
  * 每次能处理的solutions数量有限
  * 没有办法chain processing(to continue processing any remaining callouts after exceeding current limits)

batch能很好地解决这两个问题:
  * batch能处理百万级别的数据 - query甚至都不用加LastModifiedDate这个index field来filter数据(因为batch的handle能力,你可以用dataloader大批量的更改solutions);
  * batch本来不需要chain,因为batch可以处理所有需要被处理的数据;但是如果有些数据是在batch做完query之后被更改的呢?不过没关系,因为我们可以在batch的finish()方法中来start一个新的batch.
    * startBatch()方法用来启动batch(第一次或者chain的时候),该方法有以下好处:
      * 在第一次启动的时候用一个static variable `batchRequested`来判断是否已经在该execution context中启动过了batch,同时还用了一个util方法isBatchActive()来看是否当前的batch class正在运行;
      * forceStart flag可以bypass这个check,从而允许batch job在自己的finish()里restart another batch job(当前的batch job is technically running during the finish method)
      * 这个方法里还自动计算了scope(每个batch handle数据的数量) - 为callouts limit;因为每个batch execute statement都存在于它自己的execution context里面,所以不必担心别的代码会making callouts.
      * 将`Database.executeBatch()`放在了`try{}catch{}`里,如果出现异常(比如系统中已经存在了5个batch jobs而又没有enable Apex flex queue feature)则退出 - 即便退出也没有问题,因为所有需要处理的solutions都标记了TranslationPending__c为true,所以下次batch启动时会被处理.
    * 如果有些record因为某些error无法被translate,则会造成一个永无停止的batch jobs,下面是一些解决建议(更好的方法参见centralized async pattern):
      * Clear the TranslationPending__c flag for records that can’t be translated due to an unrecoverable error.
      * Use another field to mark the record as an error.
      * Keep track of the start time of the original batch, and add a DateTime filter to the query to ignore any records that were last modified before the batch was run.

batch 最大的问题的效率太低,等待时间不定且太长 - future call要快许多

* [ClassCode](src/batch/ClassCode.cls)
* [BatchClass](src/batch/BatchClass.cls)
* [TriggerCode](src/batch/TriggerCode.trigger)

### Queueable Apex

**CAUTION!**

The following section includes design patterns for asynchronous operations with queueable Apex and chaining. Used incorrectly, it is possible to create code that will spawn large numbers of execution threads very rapidly. Because it is impossible to update a class that has a queueable Apex job queued or executing, and it is possible to queue jobs faster than they can be aborted (even using anonymous Apex), you can place an org in a state where you cannot abort your code execution. Your code can run forever (or until aborted due to the 24 hour limit on asynchronous calls).

Queueable Apex code should always be gated by an on/off switch settable via a custom setting or other means that does not require a metadata change. Trust me on this – you really don’t want to find yourself in this situation.

Queueable结合了future & batch的优点,基本上思路和batch一样,但由于Queueable的一些特点,有以下注意事项:

  * If we were performing any asynchronous operation other than a callout, it would be possible to chain the async operation into a new instance of the QueueableClass class, or the current class instance using system.enqueueJob(this). However, there is currently a limitation to queueable Apex that prevents you from chaining if you have performed a callout. This, along with limits on the number of classes you can chain (which varies by type of org), and the possibility that other classes in the execution context may have queued a job, is why we not only check the limits to see if chaining is possible, but enclose the System.enqueueJob method inside of an exception handler.
  * What do you do if chaining is not allowed? How can you ensure that your work will complete? This problem will be addressed in [Centralized Asynchronous Processing](./CentralizedAsyncProcessing).


* [ClassCode](src/queueable/ClassCode.cls)
* [QueueableClass](src/queueable/QueueableClass.cls)
* [TriggerCode](src/queueable/TriggerCode.trigger)
