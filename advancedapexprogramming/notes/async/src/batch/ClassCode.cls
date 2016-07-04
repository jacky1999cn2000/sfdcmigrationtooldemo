public class ClassCode {
  public static void handleTrigger( List < Solution > solutionlist, Map < ID, Solution > oldmap, Boolean isInsert) {
    if( alreadyProcessed) return;
    alreadyProcessed = true;

    Boolean foundOne = false;
    for( Solution sl:solutionlist) {
      if( isInsert | | sl.SolutionNote! = oldMap.get( sl.id). SolutionNote) {
        sl.TranslationPending__c = true;
        foundOne = true;
      }
    }
    if(foundOne) BatchClass.startBatch(false);
}
