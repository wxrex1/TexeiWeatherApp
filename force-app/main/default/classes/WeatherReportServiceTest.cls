
@IsTest
private class WeatherReportServiceTest {

    // Simulation des réponses de l'API GeoNames
    private class GeoNamesMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader(
                'Content-Type',
                'application/json'
            );

            if (req.getEndpoint().contains('/searchJSON')) {
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
                    '"weatherCondition":"clear",' +
                    '"clouds":"few clouds",' +
                    '"datetime":"2026-10-10 12:00:00"' +
                    '}}'
                );
            }

            return res;
        }
    }

    // Création d'un Account pour les tests
    private static Account createAccount() {
        Account acc = new Account(
            Name = 'TEXEI Weather Test',
            BillingCity = 'Paris',
            BillingCountry = 'France'
        );

        insert acc;
        return acc;
    }

    // 1. Envoi depuis Home en mode test
    @IsTest
    static void testSendReportHomeTestMode() {
        Test.setMock(
            HttpCalloutMock.class,
            new GeoNamesMock()
        );

        Test.startTest();

        WeatherReportService.SendResult result =
            WeatherReportService.sendReport(
                null,
                'Paris',
                null,
                null,
                true
            );

        Test.stopTest();

        System.assertEquals(1, result.recipientCount);
        System.assertNotEquals(null, result.sentAt);
    }

    // 2. Envoi depuis Home avec coordonnées GPS
    @IsTest
    static void testSendReportCoordinates() {
        Test.setMock(
            HttpCalloutMock.class,
            new GeoNamesMock()
        );

        Test.startTest();

        WeatherReportService.SendResult result =
            WeatherReportService.sendReport(
                null,
                null,
                48.8566,
                2.3522,
                true
            );

        Test.stopTest();

        System.assertEquals(1, result.recipientCount);
        System.assertNotEquals(null, result.sentAt);
    }

    // 3. Envoi à deux contacts d'un Account
    @IsTest
    static void testSendReportAccount() {
        Account acc = createAccount();

        insert new List<Contact>{
            new Contact(
                LastName = 'Contact Test 1',
                Email = 'contact1@example.com',
                AccountId = acc.Id
            ),
            new Contact(
                LastName = 'Contact Test 2',
                Email = 'contact2@example.com',
                AccountId = acc.Id
            )
        };

        Test.setMock(
            HttpCalloutMock.class,
            new GeoNamesMock()
        );

        Test.startTest();

        WeatherReportService.SendResult result =
            WeatherReportService.sendReport(
                acc.Id,
                null,
                null,
                null,
                false
            );

        Test.stopTest();

        System.assertEquals(2, result.recipientCount);

        Account updatedAccount = [
            SELECT Last_Weather_Report_Sent__c
            FROM Account
            WHERE Id = :acc.Id
        ];

        System.assertNotEquals(
            null,
            updatedAccount.Last_Weather_Report_Sent__c
        );
    }

    // 4. Aucun contact sur le compte
    @IsTest
    static void testAccountWithoutContacts() {
        Account acc = createAccount();

        Test.setMock(
            HttpCalloutMock.class,
            new GeoNamesMock()
        );

        Boolean exceptionThrown = false;

        Test.startTest();

        try {
            WeatherReportService.sendReport(
                acc.Id,
                null,
                null,
                null,
                false
            );
        } catch (WeatherReportService.ReportException e) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'Un compte sans destinataire doit être refusé.'
        );
    }

    // 5. Aucune localisation
    @IsTest
    static void testMissingLocation() {
        Boolean exceptionThrown = false;

        Test.startTest();

        try {
            WeatherReportService.sendReport(
                null,
                null,
                null,
                null,
                true
            );
        } catch (WeatherReportService.ReportException e) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'Une localisation est obligatoire.'
        );
    }

    // 6. Lecture de la date du dernier rapport Account
    @IsTest
    static void testGetLastReportSentAccount() {
        Account acc = createAccount();

        Datetime expectedDate = System.now();

        acc.Last_Weather_Report_Sent__c = expectedDate;
        update acc;

        Test.startTest();

        Datetime actualDate =
            WeatherReportService.getLastReportSent(
                acc.Id
            );

        Test.stopTest();

        System.assertEquals(expectedDate, actualDate);
    }

    // 7. Lecture de la date du dernier rapport Home
    @IsTest
    static void testGetLastReportSentHome() {
        Test.startTest();

        Datetime result =
            WeatherReportService.getLastReportSent(null);

        Test.stopTest();

        User currentUser = [
            SELECT Last_Weather_Report_Sent__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];

        System.assertEquals(
            currentUser.Last_Weather_Report_Sent__c,
            result
        );
    }

    // 8. Vérification de la limite de 10 contacts
    @IsTest
    static void testMaximumTenRecipients() {
        Account acc = createAccount();

        List<Contact> contacts = new List<Contact>();

        for (Integer i = 0; i < 12; i++) {
            contacts.add(
                new Contact(
                    LastName = 'Test ' + i,
                    Email = 'test' + i + '@example.com',
                    AccountId = acc.Id
                )
            );
        }

        insert contacts;

        Test.setMock(
            HttpCalloutMock.class,
            new GeoNamesMock()
        );

        Test.startTest();

        WeatherReportService.SendResult result =
            WeatherReportService.sendReport(
                acc.Id,
                null,
                null,
                null,
                false
            );

        Test.stopTest();

        System.assertEquals(
            10,
            result.recipientCount,
            'Le rapport ne doit pas dépasser 10 destinataires.'
        );
    }
}
