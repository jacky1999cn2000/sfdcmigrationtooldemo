public class ClassCode {
  private static Boolean alreadyProcessed = false;

  public static void handleTrigger(List<Solution> solutionlist, Map<Id, Solution> oldmap, Boolean isInsert){
    if(alreadyProcessed) return;
    alreadyProcessed = true;
    for( Solution sl:solutionlist) {
      if( isInsert | | sl.SolutionNote! = oldMap.get( sl.id).SolutionNote)
        sl.TranslationPending__c = true;
    }
    secondAttemptRequestAsync();
  }

  public static void secondAttemptRequestAsync() {
    if( system.isFuture() | | system.isBatch())
      secondAttemptSync();
    else {
      if( Limits.getFutureCalls() < Limits.getLimitFutureCalls()-3)
        secondAttemptAsync();
    }
  }

  @future( callout = true)
  private static void secondAttemptAsync() {
    secondAttemptSync();
  }

  public static void secondAttemptSync() {
    Integer allowedCallouts = Limits.getLimitCallouts() - Limits.getCallouts();
    if( allowedCallouts < = 0) return;
    List < Solution > solutionsToUpdate = [SELECT ID, SolutionNote, SolutionSpanish__c from Solution
                                          where LastModifiedDate > :DateTime.Now(). addHours(-24) And
                                          TranslationPending__c = true LIMIT :Limits.getLimitCallouts()];
    for( Solution sl: solutionsToUpdate) {
      sl.SolutionSpanish__c = SimulatedTranslator.translate( sl.SolutionNote);
      sl.TranslationPending__c = false;
    }
    update solutionsToUpdate;
  }
}
