# Chapter 1 - 4 ThinkingInApexBulkPatterns

### Requirement:
在Opportunity的trigger当中,确保所有stagename改变了的Opportunity都有至少一个OpportunityContactRole,并且其中一个OpportunityContactRole为Primary;如果该Opportunity没有任何OpportunityContactRole,则确保有一个task被创建,提醒owner来为该Opportunity创建一个Primary OpportunityContactRole.

要确保代码支持bulk pattern - trigger里面可以一次性load进200个objects,要确保trigger里面所有的SOQL,DML,CPU Time不仅在一个object时候不违反governor limits,在200个objects(everything * 200)的时候也不违反governor limits.

伪代码如下:

* 查看Opportunity的status
* Opportunity是否有OpportunityContactRoles
  * 没有OpportunityContactRoles,是否有task已经存在
    * 存在,exit
    * 不存在，创建task,exit
  * 有OpportunityContactRoles,是否其中一个是Primary
   * 有,exit
   * 没有
    * 取得所有和这个Opportunity相关联的contacts
    * 取得所有这些contacts相关联的OpportunityContactRole
    * 对于每个contact
      * 计算这个contact有多少Primary OpportunityContactRole
      * 计算这个contact有多少OpportunityContactRole
      * 决定哪个contact可以作为Primary OpportunityContactRole(most primary,then best total if most primaries are equal)
    * 找到符合条件的contact,然后将对应的OpportunityContactRole设置为Primary OpportunityContactRole


优化代码时的一些Tips:
* 一般来说Bulk Pattern的代码最主要的是避免多重loop,因为如果外部有一个200 loop的话,里面所有的loop都会运行200次,所以第一步是先遍历一次所有的Opportunity,然后只将stagename改变的那些挑出来

* 使用nested query或复杂的数据结构 - nested query在查找时少用了SOQL,但是Apex在access nested query data时不是有效率,所以有时候可以考虑用空间换效率
```javascript
  //这样可以
  List<Opportunity> opportunitiesWithoutPrimary =
    [Select ID ,(Select ID, ContactID, IsPrimary
    from OpportunityContactRoles) from Opportunity
    where ID in :opsWithNoPrimaryWithContactRoles];

  for(Opportunity op: opportunitiesWithoutPrimary){
    for(OpportunityContactRole opOcrs: op.OpportunityContactRoles){
      ...
    }
  }


  //这样更好
  // Instead of requerying opportunties with a subquery of contact roles
  // Build a map from opportunity ID to related contact roles
  // for opportunties without primary contact roles
  Map<ID, List<OpportunityContactRole>> opportunitiesWithoutPrimary =
    new Map<ID, List<OpportunityContactRole>>();
  for(OpportunityContactRole ocr: ocrs)
  {
    ID opid = ocr.OpportunityID;	// Use temp variable for speed
    if(opsWithNoPrimaryWithContactRoles.contains(opid))
    {
      if(!opportunitiesWithoutPrimary.containsKey(opid))
        opportunitiesWithoutPrimary.put(opid, new List<OpportunityContactRole>());
      opportunitiesWithoutPrimary.get(opid).add(ocr);
    }
  }

  for(ID opid: opportunitiesWithoutPrimary.keyset()){
    for(OpportunityContactRole opOcrs: opportunitiesWithoutPrimary.get(opid)){
      ...
    }
  }
```
* 使用SOQL aggregate
  ```javascript
  // Now get the totals count and primary count for each contact by
  // using aggregate functions and grouping by contact
  List<AggregateResult> ocrsByContact =
    [Select ContactID, Count(ID) total
    from OpportunityContactRole
    where ContactID in :contactIdsForOps
    Group By ContactID];

  List<AggregateResult> primaryOcrsByContact =
    [Select ContactID, Count(ID) total
    from OpportunityContactRole where IsPrimary=true
    and ContactID in :contactIdsForOps Group By ContactID];
  ```

* 使用future - 在trigger里调用`afterUpdateOpportunityFutureSupport`,该method会在`newList.size()>100`时调用future(这个threshold不用写死,可以根据Limits来做决定,也可以写在custom setting里).`private static Boolean futureCalled`用来防止该trigger被重复call的时候不要多次call future

  ```javascript
  @future
	public static void futureUpdateOpportunities(Set<ID> opportunitiyIds)
	{
		Map<ID, Opportunity> newMap =
			new Map<ID, Opportunity>(
				[SELECT ID, OwnerID from Opportunity where ID in :opportunitiyIds]);
		afterUpdateOpportunityFutureSupport(newMap.values(), newMap, null);
	}
	private static Boolean futureCalled = false;

	public static void afterUpdateOpportunityFutureSupport(
		List<Opportunity> newList, Map<ID, Opportunity> newMap,
		Map<ID, Opportunity> oldMap)
	{
		// Pattern 6 - with future support
		Set<ID> opportunityIDsWithStagenameChanges = new Set<ID>();

		// Get OpportunityContactRoles
		if(!System.isFuture())
		{
			for(Opportunity op: newList)
			{
				if(op.StageName != oldMap.get(op.id).StageName)
					opportunityIDsWithStagenameChanges.add(op.id);
			}
			if(newList.size()>100)
			{
				if(!futureCalled)
					futureUpdateOpportunities(opportunityIDsWithStagenameChanges);
				futureCalled = true;
				return;
			}
		}
		else opportunityIDsWithStagenameChanges.addall(newMap.keyset());

    ...
  }
  ```

* 使用batch - 思路和future一样,在`newList.size()>100`时候调用batch, `private static Boolean batchCalled`确保如果该trigger被反复调用时不重复调用batch

  ```javascript
  private static Boolean batchCalled = false;

	public static void afterUpdateOpportunityBatchSupport(
		List<Opportunity> newList, Map<ID, Opportunity> newMap,
		Map<ID, Opportunity> oldMap)
	{
		// Pattern 7 - with batch support

		Set<ID> opportunityIDsWithStagenameChanges = new Set<ID>();

		// Get OpportunityContactRoles
		if(!System.isBatch())
		{
			for(Opportunity op: newList)
			{
				if(op.StageName != oldmap.get(op.id).StageName)
					opportunityIDsWithStagenameChanges.add(op.id);
			}
			if(newList.size()>100)
			{
				if(!batchCalled)
				{
					Database.executeBatch(new BulkPatternBatch(
						opportunityIDsWithStagenameChanges), 100);
				}
				batchCalled = true;
				return;
			}
		}
		else opportunityIDsWithStagenameChanges.addall(newMap.keyset());

    ...
  }

  //BulkPatternBatch - implements了Database.Batchable<sObject>的class
  global class BulkPatternBatch  implements Database.Batchable<sObject> {
    global final string query;
  	global final Set<ID> opportunityIds;


  	public bulkPatternBatch(Set<ID> opportunityIDsToUpdate)
  	{
  		opportunityids = opportunityIDsToUpdate;
  		query = 'SELECT ID, OwnerID from Opportunity where ID in :opportunityids ';
  	}

  	global Database.QueryLocator start(Database.BatchableContext BC){
  		return Database.getQueryLocator(query);
  	}

  	global void execute(Database.BatchableContext BC, List<sObject> scope){
  		List<Opportunity> ops = (List<Opportunity>)scope;
  		Map<ID, Opportunity> newmap = new Map<ID, Opportunity>(ops);
  		ThinkingInApexBulkPatterns.afterUpdateOpportunityBatchSupport(ops, newMap, null);
  		return;
  	}

  	global void finish(Database.BatchableContext BC){

  	}
  }
  ```
