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
