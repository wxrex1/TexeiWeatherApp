import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getWeatherByCity from
    '@salesforce/apex/WeatherService.getWeatherByCity';

import getWeatherByCoordinates from
    '@salesforce/apex/WeatherService.getWeatherByCoordinates';

import getWeatherByAccount from
    '@salesforce/apex/WeatherService.getWeatherByAccount';


import sendReport from
    '@salesforce/apex/WeatherReportService.sendReport';

import getLastReportSent from
    '@salesforce/apex/WeatherReportService.getLastReportSent';


export default class WeatherDashboard extends LightningElement {




get weatherEmoji() {
    if (!this.weather) {
        return '🌡️';
    }

    const description = String(
        this.weather.description || ''
    ).toLowerCase();

    if (
        description.includes('rain') ||
        description.includes('drizzle') ||
        description.includes('pluie')
    ) {
        return '🌧️';
    }

    if (
        description.includes('snow') ||
        description.includes('neige')
    ) {
        return '❄️';
    }

    if (
        description.includes('thunder') ||
        description.includes('storm') ||
        description.includes('orage')
    ) {
        return '⛈️';
    }

    if (
        description.includes('cloud') ||
        description.includes('overcast') ||
        description.includes('nuage')
    ) {
        return '☁️';
    }

    if (
        description.includes('clear') ||
        description.includes('sunny') ||
        description.includes('no cloud') ||
        description.includes('soleil')
    ) {
        return '☀️';
    }

    return '🌡️';
}




    
   
connectedCallback() {
    // Conserve l'affichage de la date du dernier rapport.
    this.loadLastReportSent();

    // Attend que Salesforce fournisse le recordId.
    // Sur Home, aucun recordId n'est normalement fourni.
    Promise.resolve().then(() => {
        if (!this.recordId) {
            this.handleGeolocation();
        }
    });
}


    async loadLastReportSent() {
        try {
            this.lastReportSent = await getLastReportSent({
                accountId: this.recordId || null
            });
        } catch (error) {
            console.error(
                'Lecture de la date impossible',
                error
            );
        }
    }


    city = '';
    weather = null;
    isLoading = false;
    errorMessage = '';

    get hasWeather() {
        return this.weather !== null;
    }

    get temperatureDisplay() {
        return this.weather?.temperature ?? '—';
    }

    get windDisplay() {
        return this.weather?.windSpeed ?? '—';
    }

    get humidityDisplay() {
        return this.weather?.humidity ?? '—';
    }

    handleCityChange(event) {
        this.city = event.target.value;
    }

    async handleSearch() {
        if (!this.city || !this.city.trim()) {
            this.errorMessage = 'Veuillez saisir une ville.';
            this.weather = null;
            return;
        }

        this.isLoading = true;
        this.errorMessage = '';
        this.weather = null;

        try {
            this.weather = await getWeatherByCity({
                city: this.city.trim()
            });
        } catch (error) {
            this.errorMessage = this.getErrorMessage(error);
        } finally {
            this.isLoading = false;
        }
    }

    handleGeolocation() {
        this.errorMessage = '';
        this.weather = null;

        if (!navigator.geolocation) {
            this.errorMessage =
                'Géolocalisation non disponible.';
            return;
        }

        this.isLoading = true;

        navigator.geolocation.getCurrentPosition(
            async (position) => {
                try {
                    this.weather = await getWeatherByCoordinates({
                        latitude: position.coords.latitude,
                        longitude: position.coords.longitude
                    });
                } catch (error) {
                    this.errorMessage =
                        this.getErrorMessage(error);
                } finally {
                    this.isLoading = false;
                }
            },
            () => {
                this.errorMessage =
                    'Impossible de récupérer votre position.';
                this.isLoading = false;
            },
            { timeout: 10000 }
        );
    }

    getErrorMessage(error) {
        return error?.body?.message ||
            error?.message ||
            'Une erreur inattendue est survenue.';
    }

    // envoie de email
    async handleSendReport() {
        if (!this.weather || this.isSending) {
            return;
        }

        this.isSending = true;
        this.errorMessage = '';

        try {
            const result = await sendReport({
                accountId: this.recordId || null,
                city: this.weather.city,
                latitude: this.weather.latitude,
                longitude: this.weather.longitude,
                testMode: this.testMode
            });

            if (!this.testMode) {
                this.lastReportSent = result.sentAt;
            }

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Rapport envoyé',
                    message:
                        result.recipientCount +
                        ' destinataire(s). ' +
                        (this.testMode
                            ? 'Mode test : votre utilisateur uniquement.'
                            : 'Envoi enregistré.'),
                    variant: 'success'
                })
            );

        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Erreur d'envoi",
                    message: this.getErrorMessage(error),
                    variant: 'error'
                })
            );
        } finally {
            this.isSending = false;
        }
    }

     // email
    isSending = false;
    lastReportSent = null;

    // À conserver à true pendant nos tests.
    testMode = false;

    get isSendDisabled() {
        return this.isSending || !this.hasWeather;
    }

    get hasLastReport() {
        return this.lastReportSent !== null;
    }


    // recupere les account id
    _accountId;
    _accountRequest = 0;

    @api
    get recordId() {
        return this._accountId;
    }

    set recordId(value) {
        if (value === this._accountId) {
            return;
        }

        this._accountId = value;

        this.loadLastReportSent();

        if (value) {
            this.loadAccountWeather();
        }
    }

    get isAccountPage() {
        return Boolean(this.recordId);
    }

    async loadAccountWeather() {
        const accountId = this.recordId;

        if (!accountId) {
            return;
        }

        const requestId = ++this._accountRequest;

        this.isLoading = true;
        this.errorMessage = '';
        this.weather = null;

        try {
            const result = await getWeatherByAccount({
                accountId: accountId
            });

            if (requestId === this._accountRequest) {
                this.weather = result;
            }
        } catch (error) {
            if (requestId === this._accountRequest) {
                this.errorMessage = this.getErrorMessage(error);
            }
        } finally {
            if (requestId === this._accountRequest) {
                this.isLoading = false;
            }
        }
    }

    
        latitudeInput = '';
        longitudeInput = '';

        handleLatitudeChange(event) {
            this.latitudeInput = event.target.value;
        }

        handleLongitudeChange(event) {
            this.longitudeInput = event.target.value;
        }

        async handleCoordinatesSearch() {
            const latText = String(this.latitudeInput).trim();
            const lngText = String(this.longitudeInput).trim();

            if (latText === '' || lngText === '') {
                this.errorMessage =
                    'Veuillez saisir une latitude et une longitude.';
                return;
            }

            const latitude = Number(latText);
            const longitude = Number(lngText);

            if (
                !Number.isFinite(latitude) ||
                !Number.isFinite(longitude) ||
                latitude < -90 ||
                latitude > 90 ||
                longitude < -180 ||
                longitude > 180
            ) {
                this.errorMessage =
                    'Coordonnées GPS invalides.';
                return;
            }

            this.isLoading = true;
            this.errorMessage = '';
            this.weather = null;

            try {
                this.weather = await getWeatherByCoordinates({
                    latitude,
                    longitude
                });
            } catch (error) {
                this.errorMessage = this.getErrorMessage(error);
            } finally {
                this.isLoading = false;
            }
        }


   

}
