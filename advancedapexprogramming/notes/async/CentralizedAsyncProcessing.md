# Centralized Async Processing

### Add SolutionSpanish__c custom field on Solution object

### Create Custom Object
Create a new object called AsyncRequest.
  * Label: AsyncRequest,
  * Plural: AsyncRequests
  * Object Name: AsyncRequest__c
  * Description: Stores asynchronous requests
  * Record Name: Async Request Name
  * Data Type: Auto Number
  * Display Format: ar-{0000}
  * Starting number: 0
  * Allow Reports
  * Uncheck: Allow activities, Track field history, Chatter
  * Uncheck: Allow Sharing, Bulk and streaming API Access (optional)

Add the following custom fields:
  * Picklist named ‘AsyncType’, with a single value ‘Translate Solution’
  * Long text area named ‘Params’, length 131072
  * Checkbox field named ‘Error’, unchecked by default
  * Long text area named ‘Error Message’, length 32768

### SolutionTrigger trigger
* [SolutionTrigger](src/centralizedasyncprocessing/SolutionTrigger.trigger)

### SolutionTriggerHandler class
It iterates over the solutions, looking at all solutions on insert, and those where the SolutionNote has changed on update. It builds a list of the IDs of the solutions that need to be translated, and then joins them into a comma separated string. It breaks up the request into groups of 100, which is the current callout limit. You can’t use the Limits.getLimitCallouts method here because it would return zero (it being a trigger context). Finally, the function creates the necessary AsyncRequest__c objects with an AsyncType__c value of “Translate Solution”, and inserts them.
* [SolutionTriggerHandler](src/centralizedasyncprocessing/SolutionTriggerHandler.cls)

### Create a custom setting instance named 'CentralizedAsyncProcessing' for AppConfig__c

### OnAsyncRequestsInsert trigger
The insertion of the AsyncRequest__c objects is detected by a new trigger called OnAsyncRequestInsert, that is defined as follows.

The enqueueGoingAsync() method is a utility function that actually enqueues the job – you’ll see why we do it that way shortly. This may seem like a lot of effort to queue up a request to process a set of solution objects to translate. The GoingAsync class, that implements the queueable interface, doesn’t get any easier.
* [OnAsyncRequestInsert](src/centralizedasyncprocessing/OnAsyncRequestInsert.trigger)

### GoingAsync class

```javascript
  AppConfig__c configData = AppConfig__c.getInstance('CentralizedAsyncProcessing');

  if(configData == null){
      return;
  }
	if(!configData.AppEnabled) return; // On/off switch

	List<AsyncRequest__c> requests;
	try{
  	requests = [Select ID, AsyncType__c, Params__c
  		from AsyncRequest__c
  		where Error__c = false And
  		CreatedById = :UserInfo.getUserId()
  		Limit 1 for update];
	}catch(Exception ex) {
		return;
	}

	if(requests.size()==0 ) return;

  AsyncRequest__c currentRequest = requests[0];
```
 * First, it filters for the Error__c field being false. This small change carries huge consequences. It means that our AsyncRequest__c object actually has two distinct purposes: it holds the requests for pending asynchronous operations, and it holds error information for those that failed with exceptions! Think about it – instead of asynchronous errors causing lost data, or obscure error messages in system logs that are discarded over time (usually right before you need them), all of the information from the original request is stored along with the exception information in as much detail as you wish to keep. And the data is reportable using standard Salesforce reporting! You can even build workflows on it that detect errors and send out notifications!
 * Next, there is a filter so that the job only processes the AsyncRequest__c objects that were created in the current user context. This is another small difference with potentially huge consequences. It means that you can implement a class to process individual requests and declare that class “with sharing” and thus respect the sharing rules of whoever requested the original async operation. Any tests for field and record level security that you make will reflect the user that originated the request. This allows you to easily implement a wide variety of security architectures - something that is difficult to do when using batch Apex or scheduled Apex to process requests that may have been placed by many different users (as was the case in our previous solutions that used the TranslationPending__c flag).
 * Finally, this query has the “For Update” qualifier, which means that no other instance of the GoingAsync class can access the record while you are processing it. As you’ll learn in the next chapter, this can dramatically reduce the chances of concurrency errors. If this instance, or another instance of the class times out with a concurrency error, who cares? The current execute method will chain to requeue the class if necessary.


 ```javascript
    try{
  		if(currentRequest.AsyncType__c=='Translate Solution')
  			translate(currentRequest);

  		// Add more here

  		delete currentRequest;
  		// Optional
  		database.emptyRecycleBin(new List<ID>{currentRequest.id}); 		
    }catch(Exception ex){
  		currentRequest.Error__c = true;
  		currentRequest.Error_Message__c = ex.getMessage();
  		update currentRequest;
    }
 ```
 * Once the request is made, the function examines the AsyncType__c field and passes the AsyncRequest__c object to the appropriate function to process the request. In this case, it’s GoingAsync.translate function that you’ll see shortly. The really important part of this function is that there is no limit to the number of AsyncType__c values you can specify (well, Salesforce does actually limit picklists currently to 1000 entries, but you can always use a text field instead in the unlikely event you have more than 1000 types of asynchronous operations).
 * The error handling system is also quite elegant. If the routine that handles a request succeeds, the framework deletes the AsyncRequest__c object, emptying it from the recycle bin so that the large number of objects being processed doesn’t interfere with normal recycle bin processing of objects people might need – like leads and contacts.
 * If, however, the method handling a request throws an exception, the routine traps the exception and marks the AsyncRequest__c object as an error, setting it’s Error__c field and storing the exception message in the ErrorMessage__c field. The record is then updated and available for later examination.

```javascript
    List<AsyncRequest__c> moreRequests = [Select ID, AsyncType__c, Params__c
												    		from AsyncRequest__c
												    		where Error__c = false
												    		and ID <> :currentRequest.id
												    		and	CreatedById = :UserInfo.getUserId()
												    		Limit 1 ];

  	if(moreRequests.size()==0) return;

		try{
			enqueGoingAsync(context.getJobId());
		}
		catch(Exception ex){
			tryToQueue();
		}
```
* All that’s left is making sure that the GoingAsync class is queued up again if necessary. First, the function performs a query similar to the first one, except that it excludes the current request and does not use the For Update option to lock the record, since the only concern here is to detect if there is another record pending.
* If a request is found, the function attempts to enqueue the class again. If that fails, typically because of a chaining limit exception or because you’ve performed a callout in the current context, it calls the tryToQueue function as a backup – a function that performs an unexpected trick as you will soon see.


```javascript
    @future
    private static void tryToQueue(){
			AppConfig__c configData = AppConfig__c.getInstance('CentralizedAsyncProcessing');

	    if(configData == null){
	        return;
	    }
    	if(!configData.AppEnabled) return; // On/off switch

    	try{
				if(Limits.getLimitQueueableJobs() - Limits.getQueueableJobs() > 0)
					enqueueGoingAsync4(null);
	    	}
    	catch(Exception ex)
    	{
    		// Wait for someone else to make a request...
    		// Or maybe use scheduled Apex?
    	}
    }
```
* The tryToQueue() method provides a backup mechanism for enqueueing the GoingAsync class. The odd thing is, that it is a future call. Everyone knows that you can’t make a future call from a batch call and you can’t create a batch from a future call. Except, it turns out that when it comes to queueable Apex, you can do both.
* Was this by design? Was it an oversight on the part of the designers that will go away someday? Who knows? At the time this book was published, this works. But what if that changes? Well, here too you can catch the exception and try yet another backup mechanism for requeueing the class. You can, for example, start a Scheduled Apex class whose sole purpose is to start queueable Apex jobs. And if even that approach fails? Remember, no data has been lost. The asynchronous request remains on the system, and eventually a new asynchronous request will come in and process the request.

```javascript
  public static void enqueueGoingAsync(ID currentJobId){
		List<AsyncApexJob> jobs = [Select ID, Status, ExtendedStatus from AsyncApexJob
					where JobType = 'Queueable' And (status='Queued' Or Status='Holding')
					And CreatedById = :userinfo.getUserID() And
					ApexClass.Name='GoingAsync' and ID!= :currentJobId Limit 1 ];
		if(jobs.size()==1) return;	// Already have one queued that isn't this one.

		System.enqueueJob(new GoingAsync());
	}
```
* The enqueueGoingAsync method calls system.enqueueJob to create the queueable Apex job, but first it checks to make sure a job isn’t already queued.
* The reason for this approach is subtle. What if you have a batch operation that is processing hundreds of records, and during that record processing you want to start an asynchronous operation? This is admittedly an unlikely scenario, but it can happen in ways you don’t anticipate if another application or process that uses batch Apex interacts with yours.
Entering large numbers of AsyncRequest__c objects isn’t a problem. And creating a large number of queueable Apex jobs isn’t a problem either **except for the fact that we’re using a For Update query to prevent concurrency errors (such as trying to process the same asynchronous request twice)**. In theory, creating large numbers of queueable Apex jobs that block each other shouldn’t be a problem – in that each one should wait in turn until it either obtains an AsyncRequest__c record or times out. **However, as it turns out, all of those queries blocking each other impose quite a load on the system, and Salesforce operations really frowns upon that**. So this scenario will likely prompt a nasty Email from them complaining that you are using too many system resources and cause them to place a delay on queueable apex in that org. **The approach shown here avoids that problem by making sure that you don’t add a new queueable job if one already exists for that class and user, which is fine, because you can rely on the chaining mechanism to ensure that the AsyncRequest__c objects are ultimately processed**.

* [GoingAsync](src/centralizedasyncprocessing/GoingAsync.cls)

### Summary

As you’ve seen, centralizing asynchronous operations using a framework such as this one has numerous benefits. It is very robust, though not quite indestructible, with great ability to recover from most exceptions. What’s more, it naturally implements an asynchronous diagnostic system – an area that is usually exceedingly painful. By filtering on the requesting user, it enables sophisticated security scenarios. It reduces the chances of DML lock errors by locking access to individual requests and, in most cases, to the records referenced by those requests.

And above all, thanks to queueable Apex, it is fast and efficient.

### Variation
What you’ve read so far represents the foundation for a centralized asynchronous processing framework. Here are a few things to consider as you look at building your own.

What would it take to retry an asynchronous operation after it has failed and it’s Error__c field has been set? All you need to do is clear the Error__c field! The record will be picked up next time the execute method runs for the originating user. You can, if you wish, use an update trigger on the AsyncRequest__c object to watch for resetting the Error__c field and queue up the Apex class at that time. You could even modify the query to accept both the user who created the AsyncRequest__c object and the person who last modified it (using the LastModifiedById field) to make sure it runs promptly.

The one type of exception that is not trappable using exception handlers are limit exceptions. If an asynchronous request for a particular AsyncRequest__c object causes a limit exception, the entire framework can get stuck as it tries over and over to process that request.

One approach to dealing with this problem is to be careful to use limit functions to check usage during each supporting function then processes the requests. If you see yourself approaching a limit, throw an exception to abort the operation and let the framework flag the AsyncRequest__c object as an error.

Here’s another trick that works as a backup. While it is true that you can’t trap limit exceptions, in the case of queueable Apex, you can detect them after the fact. You can query the AsyncApexJob object for classes that have a JobType of Queueable and that failed for the current user. If the most recent job was a failure,especially if you see more than one failed job of this type, it’s a pretty safe bet that the current record is the one that is consistently failing. You can then mark it as an error and go on to the next one.

What would it take to add a StartTime field to the AsyncRequest__c object and modify the filter so that it pulled only AsyncRequest__c objects whose start time has been met. Doing so would let you effectively schedule asynchronous requests just by setting that StartTime field. The only trick would be to make sure someone or something enqueued the Apex job for the next pending request. That remains the legitimate task of scheduled Apex.
