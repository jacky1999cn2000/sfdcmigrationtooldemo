# Chapter 5 Fun With Collections

* Using list to create map, and using map to obtain set
```javascript
  //say you have a contact list called cts
  Map<Id, Contact> contactMap = new Map<Id, Contact>(cts);
  List<Tast> tasks = [SELECT ID FROM Task WHERE Whoid in : contactMap.keyset() Limit 500];
```

* Do not use object as key since modifying object will change the hashed value and therefore same object will become a different key

* Keep track of objects to update in a map - in this way, you can update objects in different places and update them once (do not use list since you can put same objects more than once in a list, and do not use a set because modifying a object will result a new hash and result in adding same objects in set more than once).
```javascript
Map < ID, Contact > contactsToUpdate = new Map < ID, Contact >();

// First set of operations
for( Contact ct: cts) {
  // Do various operations
  // If an update is needed:
  contactsToUpdate.put( ct.id, ct);
}

// Second set of operations
for( Contact ct: cts) {
  // Do various operations
  // If an update is needed: contactsToUpdate.put( ct.id, ct);
} if( contactsToUpdate.size() > 0)

update contactsToUpdate.values();

```
