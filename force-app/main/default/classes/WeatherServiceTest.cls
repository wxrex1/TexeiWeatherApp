
@IsTest
private class WeatherServiceTest {

    private class GeoNamesMock implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');

            String endpoint = req.getEndpoint();

            if (endpoint.contains('/searchJSON')) {
                res.setBody(
                    '{"geonames":[{' +
                    '"name":"Paris",' +
                    '"countryName":"France",' +
                    '"lat":"48.8566",' +
                    '"lng":"2.3522"' +
                    '}]}'
                );
            } else {
                res.setBody(
                    '{"weatherObservation":{' +
                    '"temperature":"17",' +
                    '"windSpeed":"11",' +
                    '"humidity":"51",' +
                    '"weatherCondition":"n/a",' +
                    '"clouds":"scattered clouds",' +
                    '"datetime":"2026-10-10 12:00:00"' +
                    '}}'
                );
            }

            return res;
        }
    }

    @IsTest
    static void testWeatherByCity() {
        Test.setMock(HttpCalloutMock.class, new GeoNamesMock());

        Test.startTest();
        WeatherService.WeatherResult result =
            WeatherService.getWeatherByCity('Paris');
        Test.stopTest();

        System.assertEquals('Paris, France', result.city);
        System.assertEquals(17, result.temperature);
        System.assertEquals(51, result.humidity);
        System.assertEquals('scattered clouds', result.description);
        System.assertEquals('utility:cloud', result.icon);
        System.assertEquals(20.4, result.windSpeed);
    }

    @IsTest
    static void testWeatherByCoordinates() {
        Test.setMock(HttpCalloutMock.class, new GeoNamesMock());

        Test.startTest();
        WeatherService.WeatherResult result =
            WeatherService.getWeatherByCoordinates(
                48.8566,
                2.3522
            );
        Test.stopTest();

        System.assertEquals(17, result.temperature);
        System.assertEquals(51, result.humidity);
    }

    @IsTest
    static void testInvalidCoordinates() {
        Boolean exceptionThrown = false;

        Test.startTest();

        try {
            WeatherService.getWeatherByCoordinates(100, 200);
        } catch (WeatherService.WeatherServiceException e) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'Les coordonnées invalides doivent être refusées.'
        );
    }

    @IsTest
    static void testEmptyCity() {
        Boolean exceptionThrown = false;

        Test.startTest();

        try {
            WeatherService.getWeatherByCity('');
        } catch (WeatherService.WeatherServiceException e) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'Une ville vide doit être refusée.'
        );
    }

    @IsTest
    static void testWeatherByAccount() {
        Account acc = new Account(
            Name = 'TEXEI Test Account',
            BillingCity = 'Paris',
            BillingCountry = 'France'
        );

        insert acc;

        Test.setMock(HttpCalloutMock.class, new GeoNamesMock());

        Test.startTest();
        WeatherService.WeatherResult result =
            WeatherService.getWeatherByAccount(acc.Id);
        Test.stopTest();

        System.assertEquals('Paris, France', result.city);
        System.assertEquals(17, result.temperature);
    }

    
    // Simule différentes réponses de l'API GeoNames
    private class GeoNamesErrorMock implements HttpCalloutMock {

        private Integer statusCode;
        private String responseBody;

        GeoNamesErrorMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(responseBody);
            return res;
        }
    }

    @IsTest
    static void testCityNotFound() {
        Test.setMock(
            HttpCalloutMock.class,
            new GeoNamesErrorMock(
                200,
                '{"geonames":[]}'
            )
        );

        Boolean exceptionThrown = false;

        Test.startTest();

        try {
            WeatherService.getWeatherByCity('VilleInexistanteXYZ');
        } catch (WeatherService.WeatherServiceException e) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'Une ville introuvable doit provoquer une erreur.'
        );
    }

    @IsTest
    static void testNoWeatherObservation() {
        Test.setMock(
            HttpCalloutMock.class,
            new GeoNamesErrorMock(
                200,
                '{"weatherObservation":null}'
            )
        );

        Boolean exceptionThrown = false;

        Test.startTest();

        try {
            WeatherService.getWeatherByCoordinates(
                48.8566,
                2.3522
            );
        } catch (WeatherService.WeatherServiceException e) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'Une observation absente doit provoquer une erreur.'
        );
    }

    @IsTest
    static void testGeoNamesHttpError() {
        Test.setMock(
            HttpCalloutMock.class,
            new GeoNamesErrorMock(
                500,
                '{"error":"Internal Server Error"}'
            )
        );

        Boolean exceptionThrown = false;

        Test.startTest();

        try {
            WeatherService.getWeatherByCoordinates(
                48.8566,
                2.3522
            );
        } catch (WeatherService.WeatherServiceException e) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'Une erreur HTTP doit être gérée.'
        );
    }

    @IsTest
    static void testInvalidJson() {
        Test.setMock(
            HttpCalloutMock.class,
            new GeoNamesErrorMock(
                200,
                'ceci nest pas du JSON'
            )
        );

        Boolean exceptionThrown = false;

        Test.startTest();

        try {
            WeatherService.getWeatherByCoordinates(
                48.8566,
                2.3522
            );
        } catch (WeatherService.WeatherServiceException e) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'Un JSON invalide doit provoquer une erreur.'
        );
    }

    @IsTest
    static void testGeoNamesStatusError() {
        Test.setMock(
            HttpCalloutMock.class,
            new GeoNamesErrorMock(
                200,
                '{"status":{"message":"Invalid username","value":10}}'
            )
        );

        Boolean exceptionThrown = false;

        Test.startTest();

        try {
            WeatherService.getWeatherByCoordinates(
                48.8566,
                2.3522
            );
        } catch (WeatherService.WeatherServiceException e) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'Une erreur métier GeoNames doit être gérée.'
        );
    }

}
