import {fetchWithDedup} from './ApiClient';
import {buildApiUrls} from '../../constants/api';
import {ImageCacheService} from '../storage/ImageCacheService';
import {WeatherData, WeatherApiResponse} from '../../types/weather.types';

/**
 * Fetches weather data and downloads weather icons.
 * Mirrors WeatherModel.fetchWeatherData()
 */
export async function fetchWeather(
  domain: string,
  roomNumber: string,
  userId: string
): Promise<WeatherData | null> {
  const urls = buildApiUrls(domain, roomNumber, userId);

  const response = await fetchWithDedup<WeatherApiResponse>(
    'Weather',
    urls.weather
  );

  if (!response) {
    return null;
  }

  // Download current weather icon
  let iconLocalPath = '';
  if (response.weatherIconPath) {
    const iconUrl = `https://${domain}/catie${response.weatherIconPath}`;
    const iconName = response.weatherIconPath.split('/').pop() ?? 'weather_icon';
    try {
      const cached = await ImageCacheService.imageExists(iconName);
      if (cached) {
        iconLocalPath = ImageCacheService.getImageUri(iconName);
      } else {
        iconLocalPath = await ImageCacheService.downloadImage(iconName, iconUrl);
      }
    } catch (e) {
      console.warn('[WeatherApi] Failed to download weather icon:', e);
    }
  }

  // Download forecast icons
  const forecastDays = await Promise.all(
    (response.forecastWeatherData ?? []).slice(0, 4).map(async forecast => {
      let forecastIconPath = '';
      if (forecast.weatherIconPath) {
        const iconUrl = `https://${domain}/catie${forecast.weatherIconPath}`;
        const iconName =
          forecast.weatherIconPath.split('/').pop() ?? `forecast_${forecast.day}`;
        try {
          const cached = await ImageCacheService.imageExists(iconName);
          if (cached) {
            forecastIconPath = ImageCacheService.getImageUri(iconName);
          } else {
            forecastIconPath = await ImageCacheService.downloadImage(
              iconName,
              iconUrl
            );
          }
        } catch (e) {
          console.warn('[WeatherApi] Failed to download forecast icon:', e);
        }
      }
      return {
        day: forecast.day ?? '',
        high: forecast.maxTemp ?? '--',
        low: forecast.minTemp ?? '--',
        iconLocalPath: forecastIconPath,
        weatherText: forecast.weatherText ?? '',
      };
    })
  );

  return {
    temperature: response.temperature ?? '--°',
    city: response.city ?? '',
    temperatureText: response.temperatureText ?? '',
    date: response.date ?? '',
    iconLocalPath,
    feelsLike: response.detailedWeatherData?.feelsLike ?? response.feelsLike ?? '--',
    pressure: response.detailedWeatherData?.pressure ?? response.pressure ?? '--',
    humidity: response.detailedWeatherData?.humidity ?? response.humidity ?? '--',
    windSpeed:
      response.detailedWeatherData?.windSpeed ?? response.wind ?? '--',
    visibility:
      response.detailedWeatherData?.visibility ?? response.visibility ?? '--',
    sunRise: response.detailedWeatherData?.sunRise ?? response.sunRise ?? '--',
    sunSet: response.detailedWeatherData?.sunSet ?? response.sunSet ?? '--',
    currentDayHigh: response.maxTemp ?? '--',
    currentDayLow: response.minTemp ?? '--',
    forecast: forecastDays,
  };
}
