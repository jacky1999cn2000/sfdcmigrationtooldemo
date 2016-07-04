trigger TriggerCode on Solution (after insert, after update) {
  ClassCode.handleTrigger( trigger.new, trigger.newMap, trigger.oldMap, trigger.isInsert);
}
