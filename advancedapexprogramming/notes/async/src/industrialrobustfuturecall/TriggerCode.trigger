trigger TriggerCode on Solution (before insert, before update) {
  ClassCode.handleTrigger( trigger.new, trigger.oldMap, trigger.isInsert);
}
