
/**
 * @description Gestion des rapports météo par email.
 * Utilise WeatherService pour récupérer les données GeoNames.
 */
public with sharing class WeatherReportService {

    public class ReportException extends Exception {}

    // Limite volontaire pendant la phase de validation.
    private static final Integer MAX_RECIPIENTS = 10;

    public class SendResult {
        @AuraEnabled public Integer recipientCount { get; set; }
        @AuraEnabled public Datetime sentAt { get; set; }
    }

    /**
     * @description Envoie un rapport météo.
     * @param accountId Compte associé, ou null sur Home.
     * @param city Ville recherchée.
     * @param latitude Latitude.
     * @param longitude Longitude.
     * @param testMode True : envoi à l'utilisateur courant.
     */
    @AuraEnabled
    public static SendResult sendReport(
        Id accountId,
        String city,
        Decimal latitude,
        Decimal longitude,
        Boolean testMode
    ) {
        Boolean isTest = testMode != false;

        // 1. Récupération de la météo
        WeatherService.WeatherResult weather;

        if (accountId != null) {
            weather = WeatherService.getWeatherByAccount(
                accountId
            );
        } else if (latitude != null && longitude != null) {
            weather = WeatherService.getWeatherByCoordinates(
                latitude,
                longitude
            );
        } else if (!String.isBlank(city)) {
            weather = WeatherService.getWeatherByCity(city);
        } else {
            throw new ReportException(
                'Aucune localisation disponible.'
            );
        }

        // 2. Préparation du rapport
        String body = buildReportBody(weather);

        // 3. Sélection des destinataires
        List<Id> recipientIds = new List<Id>();

        if (isTest) {

            // Mode test : utilisateur courant uniquement
            User currentUser = getCurrentUser();

            validateEmail(currentUser.Email);

            recipientIds.add(currentUser.Id);

        } else if (accountId != null) {

            // Mode Account : contacts du compte
            recipientIds = getAccountRecipients(accountId);

        } else {

            // Mode Home : utilisateur courant uniquement
            // pendant la validation du projet.
            User currentUser = getCurrentUser();

            validateEmail(currentUser.Email);

            recipientIds.add(currentUser.Id);
        }

        if (recipientIds.isEmpty()) {
            throw new ReportException(
                'Aucun destinataire éligible trouvé.'
            );
        }

        // 4. Construction des emails
        List<Messaging.SingleEmailMessage> messages =
            new List<Messaging.SingleEmailMessage>();

        for (Id recipientId : recipientIds) {

            Messaging.SingleEmailMessage email =
                new Messaging.SingleEmailMessage();

            email.setTargetObjectId(recipientId);
            email.setSubject(
                'Rapport météo - ' + weather.city
            );
            email.setPlainTextBody(body);
            email.setSaveAsActivity(false);

            messages.add(email);
        }

        // 5. Envoi et vérification des résultats
        Messaging.SendEmailResult[] results =
            Messaging.sendEmail(messages, false);

        Integer successCount = 0;
        List<String> errors = new List<String>();

        for (Messaging.SendEmailResult result : results) {

            if (result.isSuccess()) {
                successCount++;
            } else {
                for (Messaging.SendEmailError err :
                     result.getErrors()) {

                    String detail =
                        String.valueOf(err.getStatusCode()) +
                        ' : ' + err.getMessage();

                    errors.add(detail);

                    System.debug(
                        LoggingLevel.ERROR,
                        'EMAIL ERROR : ' + detail
                    );
                }
            }
        }

        if (!errors.isEmpty()) {
            throw new ReportException(
                'Échec envoi : ' +
                String.join(errors, ' | ')
            );
        }

        // 6. Date de soumission des emails
        Datetime sentAt = System.now();

        if (!isTest) {
            saveLastSentDate(accountId, sentAt);
        }

        // 7. Résultat retourné au LWC
        SendResult output = new SendResult();
        output.recipientCount = successCount;
        output.sentAt = sentAt;

        return output;
    }

    /**
     * @description Récupère les contacts éligibles
     * associés à un Account.
     */
    
            /**
             * @description Récupère les contacts de test
             * associés à un compte Salesforce.
             */
            private static List<Id> getAccountRecipients(Id accountId) {

                List<Id> recipients = new List<Id>();

                Id requestedAccountId = accountId;

                List<Contact> contacts = [
                    SELECT Id, Email
                    FROM Contact
                    WHERE AccountId = :requestedAccountId
                    AND Email != null
                    WITH USER_MODE
                    LIMIT 10
                ];

                for (Contact c : contacts) {

                    String email = c.Email;

                    if (isUsableEmail(email)) {
                        recipients.add(c.Id);
                    }
                }

                return recipients;
            }


    /**
     * @description Récupère l'utilisateur connecté.
     */
    private static User getCurrentUser() {
        Id currentUserId = UserInfo.getUserId();

        List<User> users = [
            SELECT Id, Email
            FROM User
            WHERE Id = :currentUserId
            WITH USER_MODE
            LIMIT 1
        ];

        if (users.isEmpty()) {
            throw new ReportException(
                'Utilisateur Salesforce introuvable.'
            );
        }

        return users[0];
    }

    /**
     * @description Vérification basique de l'email.
     */
    private static Boolean isUsableEmail(String email) {
        if (String.isBlank(email)) {
            return false;
        }

        String normalized = email.trim().toLowerCase();

        return normalized.contains('@') &&
            normalized.substringAfter('@').contains('.') &&
            !normalized.startsWith('noreply@');
    }

    private static void validateEmail(String email) {
        if (!isUsableEmail(email)) {
            throw new ReportException(
                'Adresse email utilisateur invalide : ' +
                String.valueOf(email)
            );
        }
    }

    /**
     * @description Enregistre la date du dernier envoi.
     */
    private static void saveLastSentDate(
        Id accountId,
        Datetime sentAt
    ) {
        if (accountId != null) {

            Account accountToUpdate = new Account(
                Id = accountId,
                Last_Weather_Report_Sent__c = sentAt
            );

            Database.update(
                accountToUpdate,
                AccessLevel.USER_MODE
            );

        } else {

            User userToUpdate = new User(
                Id = UserInfo.getUserId(),
                Last_Weather_Report_Sent__c = sentAt
            );

            Database.update(
                userToUpdate,
                AccessLevel.USER_MODE
            );
        }
    }

    /**
     * @description Génère le contenu du rapport.
     */
    private static String buildReportBody(
        WeatherService.WeatherResult weather
    ) {
        return
            'Rapport météo Salesforce\n\n' +
            'Localisation : ' + weather.city + '\n' +
            'Température : ' +
                formatValue(weather.temperature, ' °C') + '\n' +
            'Vent : ' +
                formatValue(weather.windSpeed, ' km/h') + '\n' +
            'Humidité : ' +
                formatValue(weather.humidity, ' %') + '\n' +
            'Conditions : ' + weather.description + '\n' +
            'Observation : ' +
                (weather.observationTime == null
                    ? 'Non disponible'
                    : weather.observationTime) + '\n\n' +
            'Données fournies par GeoNames.';
    }

    private static String formatValue(
        Decimal value,
        String unit
    ) {
        return value == null
            ? 'Non disponible'
            : String.valueOf(value) + unit;
    }

    /**
     * @description Lit la date du dernier envoi.
     */
    @AuraEnabled
    public static Datetime getLastReportSent(Id accountId) {

        if (accountId != null) {

            Id requestedAccountId = accountId;

            List<Account> accounts = [
                SELECT Last_Weather_Report_Sent__c
                FROM Account
                WHERE Id = :requestedAccountId
                WITH USER_MODE
                LIMIT 1
            ];

            if (accounts.isEmpty()) {
                throw new ReportException(
                    'Compte introuvable ou inaccessible.'
                );
            }

            return accounts[0].Last_Weather_Report_Sent__c;
        }

        Id currentUserId = UserInfo.getUserId();

        List<User> users = [
            SELECT Last_Weather_Report_Sent__c
            FROM User
            WHERE Id = :currentUserId
            WITH USER_MODE
            LIMIT 1
        ];

        if (users.isEmpty()) {
            throw new ReportException(
                'Utilisateur introuvable.'
            );
        }

        return users[0].Last_Weather_Report_Sent__c;
    }
}
