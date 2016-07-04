trigger SolutionTrigger on Solution (after insert, after update) {
  SolutionTriggerHandler.handleTrigger(trigger.new, trigger.newMap, trigger.oldMap, trigger.isInsert);
}
