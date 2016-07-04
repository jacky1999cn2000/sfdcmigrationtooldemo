global class BatchClass implements Database.Batchable<SObject>, Database.AllowCallouts {

  global Database.QueryLocator start(Database.BatchableContext bc){
    return Database.getQueryLocator('SELECT ID, SolutionNote, SolutionSpanish__c FROM Solution WHERE TrackedChangeAttachment == true');
  }

  global void execute(Database.Batchable bc, List<Solutions> scope){
    for( Solution sl: scope) {
      sl.SolutionSpanish__c = SimulatedTranslator.translate( sl.SolutionNote);
      sl.TranslationPending__c = false;
    }
    update scope;
  }

  global void finish( Database.BatchableContext bc) {
    List < Solution > stillPending = [SELECT ID From Solution Where TranslationPending__c = true Limit 1];
    if( stillPending.size() > 0)
      startBatch(true);
  }

  private static Boolean batchRequested = false;

	public static void startBatch(Boolean forceStart){
		if(!forceStart && (batchRequested || isBatchActive('BatchClass')))
      return;

		BatchClass ga = new BatchClass();
		Integer batchSize = Limits.getLimitCallouts();
		if(batchSize>200) batchSize = 200;

		try{
			Database.executeBatch(ga, batchSize);
		} catch(Exception ex){
			return;
		}

		batchRequested = true;
	}

  public static Boolean isBatchActive(String classname){
		List<String> activeStatuses = new List<String>{'Completed','Aborted','Failed'};
		AsyncApexJob[] activeJobs = [select id, CompletedDate, Status, ExtendedStatus, ApexClassID
                            			from AsyncApexJob where ApexClass.Name = :classname
                            			and JobType='BatchApex'
                            			And Status Not in :activeStatuses
                            			Order By CreatedDate Desc Limit 1];
		return activeJobs.size() >0;
	}
}
