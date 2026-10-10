public with sharing class WeatherService {
    public class WeatherServiceException extends Exception {}

    private static final String USERNAME = 'wxrex';
    private static final String BASE_URL = 'callout:GeoNames_API';

    // Données envoyées au composant LWC
    public class WeatherResult {
        @AuraEnabled public String city;
        @AuraEnabled public Decimal latitude;
        @AuraEnabled public Decimal longitude;
        @AuraEnabled public Decimal temperature;
        @AuraEnabled public Decimal windSpeed;
        @AuraEnabled public Decimal humidity;
        @AuraEnabled public String description;
        @AuraEnabled public String icon;
        @AuraEnabled public String observationTime;
    }

    // Recherche météo par nom de ville
    @AuraEnabled
    public static WeatherResult getWeatherByCity(String city) {

        if (String.isBlank(city)) {
            throw new WeatherServiceException(
                'Veuillez saisir une ville.'
            );
        }

        String endpoint = BASE_URL + '/searchJSON'
            + '?q=' + EncodingUtil.urlEncode(city.trim(), 'UTF-8')
            + '&maxRows=1'
            + '&featureClass=P'
            + '&username=' + USERNAME;

        Map<String, Object> response = callGeoNames(endpoint);

        List<Object> places =
            (List<Object>) response.get('geonames');

        if (places == null || places.isEmpty()) {
            throw new WeatherServiceException(
                'Ville introuvable.'
            );
        }

        Map<String, Object> place =
            (Map<String, Object>) places[0];

        Decimal lat = Decimal.valueOf(
            String.valueOf(place.get('lat'))
        );

        Decimal lng = Decimal.valueOf(
            String.valueOf(place.get('lng'))
        );

        String cityName = String.valueOf(place.get('name'));

        if (place.get('countryName') != null) {
            cityName += ', ' +
                String.valueOf(place.get('countryName'));
        }

        return getWeather(lat, lng, cityName);
    }

    // Recherche météo par coordonnées GPS
    @AuraEnabled
    public static WeatherResult getWeatherByCoordinates(
        Decimal latitude,
        Decimal longitude
    ) {
        return getWeather(latitude, longitude, null);
    }

    private static WeatherResult getWeather(
        Decimal lat,
        Decimal lng,
        String cityName
    ) {
        if (lat == null || lng == null ||
            lat < -90 || lat > 90 ||
            lng < -180 || lng > 180) {

            throw new WeatherServiceException(
                'Coordonnées GPS invalides.'
            );
        }

        String endpoint = BASE_URL + '/findNearByWeatherJSON'
            + '?lat=' + String.valueOf(lat)
            + '&lng=' + String.valueOf(lng)
            + '&username=' + USERNAME;

        Map<String, Object> response = callGeoNames(endpoint);

        Map<String, Object> observation =
            (Map<String, Object>) response.get(
                'weatherObservation'
            );

        if (observation == null) {
            throw new WeatherServiceException(
                'Aucune observation météo disponible.'
            );
        }

        WeatherResult result = new WeatherResult();

        result.city = String.isBlank(cityName)
            ? 'GPS : ' + lat + ', ' + lng
            : cityName;

        result.latitude = lat;
        result.longitude = lng;

        result.temperature =
            parseDecimal(observation.get('temperature'));

        // GeoNames retourne le vent en noeuds.
        Decimal windKnots =
            parseDecimal(observation.get('windSpeed'));

        result.windSpeed = windKnots == null
            ? null
            : (windKnots * 1.852).setScale(1);

        // Certaines stations ne fournissent pas l'humidité.
        result.humidity =
            parseDecimal(observation.get('humidity'));

        String condition = observation.get('weatherCondition')
            == null ? '' :
            String.valueOf(observation.get('weatherCondition'));

        String clouds = observation.get('clouds')
            == null ? '' :
            String.valueOf(observation.get('clouds'));

        
Boolean hasCondition =
    !String.isBlank(condition) &&
    condition.toLowerCase() != 'n/a';

Boolean hasClouds =
    !String.isBlank(clouds) &&
    clouds.toLowerCase() != 'n/a';

if (hasCondition) {
    result.description = condition;
} else if (hasClouds) {
    result.description = clouds;
} else {
    result.description = 'Conditions indisponibles';
}


        
String summary = (
    (hasCondition ? condition : '') + ' ' +
    (hasClouds ? clouds : '')
).toLowerCase();

if (summary.contains('rain') ||
    summary.contains('drizzle')) {

    result.icon = 'utility:water';

} else if (summary.contains('snow')) {

    result.icon = 'utility:priority';

} else if (summary.contains('cloud') ||
           summary.contains('overcast')) {

    result.icon = 'utility:cloud';

} else if (summary.contains('clear') ||
           summary.contains('sunny')) {

    result.icon = 'utility:dayview';

} else {

    result.icon = 'utility:world';
}


        result.observationTime =
            observation.get('datetime') == null
            ? null
            : String.valueOf(observation.get('datetime'));

        return result;
    }

    // Conversion sécurisée en nombre
    private static Decimal parseDecimal(Object value) {
        if (value == null ||
            String.isBlank(String.valueOf(value))) {
            return null;
        }

        try {
            return Decimal.valueOf(String.valueOf(value));
        } catch (Exception e) {
            return null;
        }
    }

    // Appel HTTP vers GeoNames
    private static Map<String, Object> callGeoNames(
        String endpoint
    ) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setTimeout(15000);

        HttpResponse res;

        try {
            res = new Http().send(req);
        } catch (Exception e) {
            throw new WeatherServiceException(
                'Impossible de contacter GeoNames : '
                + e.getMessage()
            );
        }

        if (res.getStatusCode() != 200) {
            throw new WeatherServiceException(
                'Erreur HTTP GeoNames : ' +
                res.getStatusCode()
            );
        }

        Map<String, Object> data;

        try {
            data = (Map<String, Object>)
                JSON.deserializeUntyped(res.getBody());
        } catch (Exception e) {
            throw new WeatherServiceException(
                'Réponse JSON GeoNames invalide.'
            );
        }

        if (data == null) {
            throw new WeatherServiceException(
                'Réponse GeoNames vide.'
            );
        }

        if (data.containsKey('status')) {
            Map<String, Object> status =
                (Map<String, Object>) data.get('status');

            throw new WeatherServiceException(
                'GeoNames : ' +
                String.valueOf(status.get('message'))
            );
        }

        return data;
    }

    
/**
 * @description Récupère la météo associée
 * à l'adresse de facturation d'un compte.
 * @param accountId Identifiant du compte Salesforce.
 * @return WeatherResult Données météorologiques.
 */
@AuraEnabled
public static WeatherResult getWeatherByAccount(Id accountId) {

    if (accountId == null) {
        throw new WeatherServiceException(
            'Identifiant du compte manquant.'
        );
    }

    
    Id requestedAccountId = accountId;

    List<Account> accounts = [
        SELECT Id, Name, BillingCity, BillingCountry,
            BillingLatitude, BillingLongitude
        FROM Account
        WHERE Id = :requestedAccountId
        WITH USER_MODE
        LIMIT 1
    ];


    if (accounts.isEmpty()) {
        throw new WeatherServiceException(
            'Compte introuvable ou inaccessible.'
        );
    }

    Account acc = accounts[0];

    // Priorité aux coordonnées géographiques
    if (acc.BillingLatitude != null &&
        acc.BillingLongitude != null) {

        return getWeatherByCoordinates(
            acc.BillingLatitude,
            acc.BillingLongitude
        );
    }

    // Sinon, recherche à partir de la ville
    if (String.isBlank(acc.BillingCity)) {
        throw new WeatherServiceException(
            'Ce compte ne possède pas de ville de facturation.'
        );
    }

    String location = acc.BillingCity;

    if (!String.isBlank(acc.BillingCountry)) {
        location += ', ' + acc.BillingCountry;
    }

    return getWeatherByCity(location);
}

}
