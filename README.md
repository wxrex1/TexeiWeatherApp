# TEXEI Weather Dashboard

A Salesforce weather application built with **Lightning Web Components (LWC)** and **Apex**, integrating the **GeoNames** weather API. The dashboard displays current available weather observations and allows users to send weather reports by email from Salesforce Home and Account record pages.

## Features

### Home page
- Search for weather by city name.
- Request weather using the browser's geolocation (subject to browser permission).
- Enter latitude and longitude manually.
- Display location, temperature (°C), wind speed (km/h), humidity (%), and weather conditions with an emoji-based weather symbol.
- Email a weather report to the current Salesforce user.
- Display the timestamp of the most recently sent report, when available.

### Account record page
- Look up weather based on the Account billing address/location.
- Display weather details in the same dashboard.
- Send weather reports to eligible Contacts associated with the Account (up to **10 recipients**).
- Display the last report timestamp for the Account.

### Error handling
- Handle invalid or missing location inputs.
- Handle cities not found, missing weather observations, API errors, and malformed responses.
- Show a fallback weather description when the API does not provide a usable condition.

## Technical architecture

| Component | Responsibility |
| --- | --- |
| `weatherDashboard` (LWC) | Salesforce UI, search and GPS interactions, weather presentation, email actions, last-sent display |
| `WeatherService.cls` | GeoNames HTTP callouts, location lookup, weather parsing and validation |
| `WeatherReportService.cls` | Recipient selection, email composition and sending, last-sent timestamp persistence |
| `WeatherServiceTest.cls` | Mocked API responses and weather service unit tests |
| `WeatherReportServiceTest.cls` | Email-report and last-sent-date unit tests |
| `GeoNames_API` (Named Credential) | Salesforce configuration for outbound requests to GeoNames |
| `Last_Weather_Report_Sent__c` | Custom Date/Time field used on Account and User records |

**Request flow:** LWC → Apex (`WeatherService`) → GeoNames API → weather data → LWC. When a report is requested, the LWC calls `WeatherReportService`, which obtains weather data, selects recipients, sends Salesforce emails, and records the send timestamp when not in test mode.

## Prerequisites

- A Salesforce org with Lightning Experience and permission to deploy Apex and Lightning Web Components.
- Salesforce CLI (`sf`) and a Salesforce DX project.
- Access to GeoNames web services and a valid GeoNames username.
- A configured Salesforce Named Credential called **`GeoNames_API`** that matches the Apex callout configuration.
- Required access to Account, Contact, User, and the custom timestamp fields.

> **Security:** Do not commit passwords, access tokens, private credentials, or org authentication files. Configure credentials in the target Salesforce org. The GeoNames username and any endpoint/authentication settings must match the deployed Apex implementation.

## Salesforce setup

1. Authenticate to your target org using Salesforce CLI.
2. Configure the GeoNames integration and the `GeoNames_API` Named Credential in the target org. Ensure the integration user and endpoint settings are valid.
3. Ensure the custom **Date/Time** field `Last_Weather_Report_Sent__c` exists on **Account** and **User**, and grant the required field permissions.
4. Deploy the Salesforce metadata from the project.
5. Add `weatherDashboard` to the **Home** page and the **Account Record** page using Lightning App Builder, then activate the pages as needed.
6. Verify that the user can access the component, relevant records, and the GeoNames callout.

Example deployment (after authenticating to the org):

```bash
sf project deploy start --source-dir force-app/main/default --target-org "Texei Meteo"
```

The alias `Texei Meteo` is an example local Salesforce CLI alias; replace it with the alias or username for your target org.

## Using the application

**Home:** Open the Lightning Home page, then search by city, click **Ma position** to use browser geolocation, or enter coordinates and click **Rechercher par GPS**. Use **Envoyer le rapport météo** to email the current user.

**Account:** Open an Account record with a usable billing location. Review the displayed weather and use **Envoyer le rapport météo** to email eligible Contacts associated with the Account. The application limits recipient selection to 10 Contacts.

The API's weather coverage and freshness depend on GeoNames. Missing conditions may be displayed as unavailable rather than fabricated.

## Email behavior

The Apex `WeatherReportService.sendReport(accountId, city, latitude, longitude, testMode)` method:

- Uses the Account when `accountId` is supplied; otherwise uses coordinates if both are supplied, or the city name.
- Sends to the current Salesforce user when `testMode` is enabled.
- Sends to eligible Account Contacts (maximum 10) when `testMode` is disabled and an Account is supplied.
- Sends to the current Salesforce user for Home reports when `testMode` is disabled.
- Returns the successful recipient count and send timestamp.
- Updates `Last_Weather_Report_Sent__c` on the Account or current User **only when `testMode` is disabled**.

The service uses Salesforce email APIs; actual email delivery is subject to org configuration, permissions, and email deliverability settings.

## Automated tests

Apex unit tests use `HttpCalloutMock` so the test suite does not depend on live GeoNames responses. Salesforce Apex test email operations do not deliver real emails.

Run both suites:

```bash
sf apex run test --class-names WeatherServiceTest,WeatherReportServiceTest --target-org "Texei Meteo" --result-format human --code-coverage --wait 10
```

### Recorded test results

| Metric | Result |
| --- | ---: |
| `WeatherServiceTest` | 10 passed / 10 |
| `WeatherReportServiceTest` | 8 passed / 8 |
| `WeatherService` coverage | 81% |
| `WeatherReportService` coverage | 79% |
| Reported org-wide Apex coverage | 79% |

These values come from the project's test runs in the development org and can change as code or org metadata changes. Run the suites again in the target org to confirm current results.

The weather tests include city lookup, GPS lookup, Account lookup, input validation, HTTP errors, missing observations, invalid JSON, and GeoNames status errors. The report tests cover Home and Account emails, coordinates, missing locations, empty recipient lists, last-sent timestamps, and the 10-recipient limit.

## Known limitations

- Weather data depends on the GeoNames API, its geographic coverage, and the availability of nearby observations.
- The dashboard displays available observations, which may not represent real-time conditions at the exact requested coordinates.
- Weather symbols are Unicode emojis; their appearance varies by browser and operating system.
- Email recipients are limited to 10 Account Contacts by the current implementation.
- Email delivery and record updates depend on Salesforce permissions and org configuration.
- The Named Credential and any environment-specific configuration must be set up separately in each target org.

## Project delivery checklist

- [ ] Verify Home and Account dashboard behavior in the target org.
- [ ] Confirm the Named Credential and required permissions.
- [ ] Run both Apex test classes in the target org.
- [ ] Ensure the repository contains no secrets or local authentication files.
- [ ] Add screenshots if desired, ensuring no personal data or credentials are visible.

---

**Project:** TEXEI technical assessment — Salesforce Weather Dashboard.
