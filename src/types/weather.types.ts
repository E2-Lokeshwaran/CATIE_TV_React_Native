export interface WeatherData {
  temperature: string;
  city: string;
  temperatureText: string;
  date: string;
  iconLocalPath: string;
  feelsLike: string;
  pressure: string;
  humidity: string;
  windSpeed: string;
  visibility: string;
  sunRise: string;
  sunSet: string;
  currentDayHigh: string;
  currentDayLow: string;
  forecast: ForecastDay[];
}

export interface ForecastDay {
  day: string;
  high: string;
  low: string;
  iconLocalPath: string;
  weatherText: string;
}

export interface WeatherApiResponse {
  status?: string;
  temperature?: string;
  city?: string;
  temperatureText?: string;
  date?: string;
  weatherIconPath?: string;
  feelsLike?: string;
  pressure?: string;
  humidity?: string;
  wind?: string;
  visibility?: string;
  sunRise?: string;
  sunSet?: string;
  maxTemp?: string;
  minTemp?: string;
  forecastWeatherData?: ForecastApiItem[];
  detailedWeatherData?: DetailedWeatherApiItem;
}

export interface ForecastApiItem {
  day: string;
  maxTemp: string;
  minTemp: string;
  weatherIconPath?: string;
  weatherText?: string;
}

export interface DetailedWeatherApiItem {
  feelsLike?: string;
  pressure?: string;
  humidity?: string;
  windSpeed?: string;
  visibility?: string;
  sunRise?: string;
  sunSet?: string;
}
