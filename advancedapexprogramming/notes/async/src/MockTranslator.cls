global class MockTranslator implements HttpCalloutMock {
	global HttpResponse respond (HttpRequest req){
		String requestBody = req.getBody();
		HttpResponse res = new HttpResponse();
		res.setHeader('Content-Type', 'text');
		res.setBody(requestBody + ' in Spanish');
		res.setStatusCode(200);
		return res;
	}
}
