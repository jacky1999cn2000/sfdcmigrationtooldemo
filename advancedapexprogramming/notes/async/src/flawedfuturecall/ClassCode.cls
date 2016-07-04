public class ClassCode {
  private static Boolean alreadyProcessed = false;

  public static void handleTrigger( List < Solution > solutionList, Map < ID, Solution > newMap, Map < ID, Solution > oldMap, Boolean isInsert) {
    if( alreadyProcessed) return;
    alreadyProcessed = true;
    if( isInsert)
      firstAttempt( newMap.keyset());
    else {
      Set < ID > textChangedIds = new Set < ID >();
      for( Solution sl: solutionList) {
        if( sl.SolutionNote! = oldMap.get( sl.id). SolutionNote)
          textChangedIds.add( sl.id);
        }
        if( textChangedIds.size() > 0)
          firstAttempt( textChangedIds);
    }
  }

  @future( callout = true)
  public static void firstAttempt( Set < ID > solutionIds) {
    List < Solution > solutionsToUpdate = [SELECT ID, SolutionNote, SolutionSpanish__c from Solution where ID in :solutionids];
    for( Solution sl: solutionsToUpdate)
      sl.SolutionSpanish__c = SimulatedTranslator.translate( sl.SolutionNote);

    update solutionsToUpdate;
  }
}
