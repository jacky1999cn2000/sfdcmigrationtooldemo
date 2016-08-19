# Platform Dev I

[Passing the Salesforce Certified Platform Developer 1 Exam](https://medium.com/appiphony-llc/passing-the-salesforce-certified-platform-developer-1-exam-6ecd5fbdfe1f#.jrkzux9qv)

NOTES:

* [Accounts and Contacts](https://developer.salesforce.com/trailhead/admin_intro_accounts_contacts/admin_intro_accounts_contacts_relationships)
  * Contacts to multiple Accounts
    * 有些时候,一个contact可以和多个accounts联系(比如这个contact是一个consultant,为多个accounts做过咨询),这个时候,可以使用contacts to multiple accounts feature;
    * 去Account Settings里面enable "contacts to multiple accounts"
    * 在Account的page layout里面添加"related contacts"到related lists里面, 去Contact的page layout里面添加"related accounts"到related list里面
    * 在Account的related contacts里添加新的relation或修改已有的relation
    * 每个account有一个main contact,每个contact有自己的title和role
    * Decide whether you want to prevent activities from automatically rolling up to a contact’s primary account. If so, from Setup, go to the Activities Settings page and deselect Roll up activities to a contact's primary account.

  * Account Hierarchies
    * 根据account的parent account来建立Hierarchies(在account detail page选择View Hierarchies)
    * 对于有多个location的公司,建议每一个location设置一个account,使用Hierarchies

  * Account Teams
    * 在 Customize | Accounts | Account Teams 里enable Account Teams
    * 将Account Teams添加到account page layout related list里面
    * 每一个account可以添加account team member
    * 如果有一个固定的account team,则可以在 User Settings | Advanced User Details 里设置default account team

* [Testing Http Callout](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_restful_http_testing.htm)
  * [Testing HTTP Callouts with Static Data](https://developer.salesforce.com/blogs/developer-relations/2012/10/testing-http-callouts-with-static-data-in-winter-13.html?language=en)
  * [Testing Apex Callouts using HttpCalloutMock](https://developer.salesforce.com/blogs/developer-relations/2013/03/testing-apex-callouts-using-httpcalloutmock.html)

* [Loading Test Data](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_load_data.htm)

* [Adding SOSL Queries to Unit Tests](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_SOSL.htm)
