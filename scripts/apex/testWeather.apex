WeatherService.WeatherResult weather =
    WeatherService.getWeatherByCity('Paris');

System.debug('VILLE : ' + weather.city);
System.debug('TEMPERATURE : ' + weather.temperature);
System.debug('VENT : ' + weather.windSpeed);
System.debug('HUMIDITE : ' + weather.humidity);
System.debug('CONDITIONS : ' + weather.description);
System.debug('OBSERVATION : ' + weather.observationTime);
