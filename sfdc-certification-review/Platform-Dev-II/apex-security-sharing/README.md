# with sharing & without sharing

[Salesforce - "System mode & User mode" and "With sharing & Without sharing" keywords](http://knowsalesforce.blogspot.in/2014/02/salesforce-system-mode-user-mode-and.html)
[Enforcing Sharing Rules](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_security_sharing_rules.htm)

如同第一篇文章里说的那样，一般来说 with sharing & without sharing 不会影响DML,只会影响SOQL SOSL,因为apex always have access to all sObjects and fields regardless of user's permissions. 然而, 像第二个链接(文档)最后说的那样,有些时候当设定with sharing,而user没有某一个foreign key access的时候, DML还是会失败

# Enforcing object and field permissions
[Enforcing Object and Field Permissions](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_perms_enforcing.htm)
