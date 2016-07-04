# Chapter 7 Going Asynchronous

### Requirements
Consider a scenario where you are building a knowledge base using Solution objects, and wish to add a field that contains the machine translation of the solution details, say, to Spanish. You want to build an application that will automatically populate a new custom field, SolutionSpanish__c, on insertion or update of the Solution object. To perform the translation, you’ll use an external web service, such as Google Translate or Microsoft Translate.

### Set Stage
直接调用Google Translate service比较麻烦,所以写了一个SimulatedTranslator来模拟translate service,同时定义了一个实现了HttpCalloutMock接口的类用来返回模拟的Httprespons.
* [SimulatedTranslator](src/SimulatedTranslator.cls)
* [MockTranslator](src/MockTranslator.cls)

### Solution 1
* [Solutio1Trigger](src/Solutio1Trigger.cls)
* [Solution1](src/Solutio1.cls)
