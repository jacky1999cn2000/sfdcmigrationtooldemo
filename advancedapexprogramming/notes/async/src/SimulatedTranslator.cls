global class SimulatedTranslator {
	public static String translate (String sourceText){
		HttpRequest req = new HttpRequest();
		req.setBody(sourceText);
		req.setHeader('Content-Type', 'text');
		HttpResponse result = translate(req);
		return result.getBody();
	}

	public static HttpResponse translate(HttpRequest req){
		/*
			Just simulate the call for now
			remove this if you've implemented real translation
		*/
		if(!Test.isRunningTest()){
			MockTranslator mock = new MockTranslator();
			return mock.respond(req);
		}
		/*
			Replace following with a call to actual translation service
			only put it here as placeholder since we have to return a HttpResponse for the method
		*/
		req.setEndpoint('http://api.salesforce.com/foo/bar');
		req.setMethod('GET');
		Http h = new Http();
		HttpResponse res = h.send(req);
		return res;
	}
}
