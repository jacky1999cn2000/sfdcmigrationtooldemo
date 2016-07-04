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
* [TriggerCode](src/flawedfuturecall/TriggerCode.cls)

### Industrial Robust Future Call

首先要有个方法来保存所有需要被处理的solutions的id,为此,我们在Solution object上添加一个custom field - TranslationPending__c; 我们使用了before trigger,因为这样可以便于操作TranslationPending__c.

* [ClassCode](src/industrialrobustfuturecall/ClassCode.cls)
* [TriggerCode](src/industrialrobustfuturecall/TriggerCode.cls)
