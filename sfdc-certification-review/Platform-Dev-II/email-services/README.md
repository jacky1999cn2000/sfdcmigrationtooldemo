# Salesforce Email Services

* [An Introduction to Email Services](https://developer.salesforce.com/page/An_Introduction_To_Email_Services_on_Force.com)

简而言之,Email Services的内容如下:
* Inbound Email Service(收邮件)
  * `Messaging.InboundEmailResult handleInboundEmail(Messaging.inboundEmail email, Messaging.InboundEnvelope envelope)` 写一个实现这个interface的apex class
  * 在`Log into Force.com and select on Setup->App Setup->Develop->Email Services`中新建一个Email Service
  * 选择`New Email Address`创建一个或多个email address
* Outbound Email Service
  * Sending Single Emails
  * Mass Email
