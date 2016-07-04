trigger SolutionTrigger1 on Solution (after insert, after update) {
  Solution1.handleTrigger1( trigger.new, trigger.newMap, trigger.oldMap, trigger.isInsert); 
}
