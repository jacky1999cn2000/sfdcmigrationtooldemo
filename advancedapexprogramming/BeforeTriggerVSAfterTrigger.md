# Before Trigger vs After Trigger

### Before Trigger:
  * GOOD:
    * any field changes you make to an object do not require a SOQL or DML operation
    * have access to all of the object's fields
  * BAD:
    * ID not yet exist during a before-insert trigger
    * formula field not yet be updated based on the new field value during an update trigger, or set at all during an insert trigger

Use after triggers when you need to reference formula fields or make sure that any related records (lookups, etc.) are set after an insert or update. For example: when an Opportunity is created off of a Contact record, the OpportunityContactRole for that contact is only available during the after-insert trigger.

By the same token, use a before-delete trigger to be able to access existing related records (lookups, etc.) before they are deleted or reparented.

Always use after triggers to detect lead conversions. Depending on the lead settings, the before triggers may not even fire.
