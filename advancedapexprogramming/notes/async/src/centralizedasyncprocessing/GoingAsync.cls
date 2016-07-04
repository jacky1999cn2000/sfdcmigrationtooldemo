public with sharing class GoingAsync implements queueable, Database.AllowsCallouts{

	public void execute(QueueableContext context){
			AppConfig__c configData = AppConfig__c.getInstance('CentralizedAsyncProcessing');

	    if(configData == null){
	        return;
	    }
    	if(!configData.AppEnabled__c) return; // On/off switch

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

    	try{
    		if(currentRequest.AsyncType__c=='Translate Solution')
    			translate(currentRequest);

    		// Add more here

    		delete currentRequest;
    		// Optional
    		database.emptyRecycleBin(new List<ID>{currentRequest.id});

    	}
    	catch(Exception ex){
    		currentRequest.Error__c = true;
    		currentRequest.Error_Message__c = ex.getMessage();
    		update currentRequest;
    	}

    	List<AsyncRequest__c> moreRequests = [Select ID, AsyncType__c, Params__c
												    		from AsyncRequest__c
												    		where Error__c = false
												    		and ID <> :currentRequest.id
												    		and	CreatedById = :UserInfo.getUserId()
												    		Limit 1 ];

    	if(moreRequests.size()==0) return;

			try{
				enqueueGoingAsync(context.getJobId());
			}
			catch(Exception ex){
				tryToQueue();
			}

    }

		@future
    private static void tryToQueue(){
			AppConfig__c configData = AppConfig__c.getInstance('CentralizedAsyncProcessing');

	    if(configData == null){
	        return;
	    }
    	if(!configData.AppEnabled__c) return; // On/off switch

    	try{
				if(Limits.getLimitQueueableJobs() - Limits.getQueueableJobs() > 0)
					enqueueGoingAsync(null);
	    	}
    	catch(Exception ex)
    	{
    		// Wait for someone else to make a request...
    		// Or maybe use scheduled Apex?
    	}
    }

		public static void enqueueGoingAsync(ID currentJobId){
			List<AsyncApexJob> jobs = [Select ID, Status, ExtendedStatus from AsyncApexJob
						where JobType = 'Queueable' And (status='Queued' Or Status='Holding')
						And CreatedById = :userinfo.getUserID() And
						ApexClass.Name='GoingAsync' and ID!= :currentJobId Limit 1 ];
			if(jobs.size()==1) return;	// Already have one queued that isn't this one.

			System.enqueueJob(new GoingAsync());
		}

		public void translate(AsyncRequest__c request){
    	Integer allowedCallouts = Limits.getLimitCallouts() - Limits.getCallouts();
			if(allowedCallouts<=0) return;

			List<ID> idsAfterSplit = request.Params__c.split(',');

			List<Solution> solutionsToUpdate = [SELECT ID, SolutionNote, SolutionSpanish__c
																					from Solution
																					where ID in :idsAfterSplit
																					LIMIT :allowedCallouts];
			for(Solution sl: solutionsToUpdate){
				sl.SolutionSpanish__c = SimulatedTranslator.translate(sl.SolutionNote);
				// sl.TranslationPending__c = false;
			}
			update solutionsToUpdate;
    }
}
