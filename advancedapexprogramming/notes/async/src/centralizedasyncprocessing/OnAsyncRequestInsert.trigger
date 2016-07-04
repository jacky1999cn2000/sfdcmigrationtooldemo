trigger OnAsyncRequestInsert on AsyncRequest__c (after insert) {
  if(Limits.getLimitQueueableJobs() - Limits.getQueueableJobs() > 0)
		try{
			GoingAsync.enqueueGoingAsync(null);
		} catch(Exception ex){
			// Ignore for now
		}
}
