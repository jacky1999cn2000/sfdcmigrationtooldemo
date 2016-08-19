# Single Sign On

* [Social Sign-On intro](https://www.youtube.com/watch?v=daQf0mMqWI4)
* [Social Single Sign-On with OpenID Connect (with ChatterInApex and Google Drive)](https://www.youtube.com/watch?v=XIFMnzbG5Ew)
* [OpenID Connect and Single Sign-On for Beginners (a thorough demo explaining both SFDC as client and auth server)](https://www.youtube.com/watch?v=T1fpulzHYcs)

* [Login to Salesforce from Salesforce using Authentication Provider](http://www.jitendrazaa.com/blog/salesforce/login-to-salesforce-from-salesforce-using-authentication-provider/#more-4516)
  *  我觉得文章说颠倒了...反正不管怎么样,client使用Auth.Provider, IdP(identity provider)创建connected app, client通过IdP登录之后使用RegistrationHandler来createUser or updateUser, 而且还可以在apex中通过`Auth.AuthToken.getAccessToken`来获取access_token, 进而访问IdP里的其他资源

* [Salesforce to Salesforce integration using Named Credentials in 5 lines](http://www.jitendrazaa.com/blog/salesforce/salesforce-to-salesforce-integration-using-named-credentials-in-just-5-lines-of-code/)
  * 创建Named Credential时如果选择Oauth Auth,当下就要进行验证

* [Let's play with Named Credentials and OAuth 2.0](http://blog.enree.co/2016/03/salesforce-apex-lets-play-with-named.html)
  * **这篇写的极为清晰!!!**
