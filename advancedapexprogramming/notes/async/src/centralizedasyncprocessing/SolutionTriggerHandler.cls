public with sharing class SolutionTriggerHandler {
	private static Boolean alreadyProcessed = false;

	public static void handleTrigger(List<Solution> solutionList, Map<ID, Solution> newMap, Map<ID, Solution> oldMap, Boolean isInsert){

		if(alreadyProcessed) return;
		alreadyProcessed = true;

		List<AsyncRequest__c> newAsyncRequests = new List<AsyncRequest__c>();

		List<String> textChangedIds = new List<ID>();
		for(Solution sl: solutionList){
			if(isInsert || sl.SolutionNote!= oldMap.get(sl.id).SolutionNote)
				textChangedIds.add(sl.id);

			if(textChangedIds.size()>=100){
				newAsyncRequests.add(
					new AsyncRequest__c(AsyncType__c = 'Translate Solution',
															Params__c = string.Join(textChangedIds,','))
				);
				textChangedIds.clear();
			}
		}

		if(textChangedIds.size()>0)
			newAsyncRequests.add(
				new AsyncRequest__c(AsyncType__c = 'Translate Solution',
														Params__c = string.Join(textChangedIds,','))
			);

		insert newAsyncRequests;
	}
}
