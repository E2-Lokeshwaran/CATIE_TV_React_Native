import {create} from 'zustand';
import {WeatherData, ForecastDay} from '../types/weather.types';

interface WeatherState {
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
  isLoaded: boolean;
  showDetailedWeather: boolean; // toggle between detailed and 4-day (UI type 1 only)
}

interface WeatherActions {
  setWeatherData: (data: WeatherData) => void;
  toggleWeatherView: () => void;
  clearWeather: () => void;
}

export const useWeatherStore = create<WeatherState & WeatherActions>(set => ({
  temperature: '--°',
  city: '',
  temperatureText: '',
  date: '',
  iconLocalPath: '',
  feelsLike: '--',
  pressure: '--',
  humidity: '--',
  windSpeed: '--',
  visibility: '--',
  sunRise: '--',
  sunSet: '--',
  currentDayHigh: '--',
  currentDayLow: '--',
  forecast: [],
  isLoaded: false,
  showDetailedWeather: true,

  setWeatherData: data =>
    set({
      temperature: data.temperature,
      city: data.city,
      temperatureText: data.temperatureText,
      date: data.date,
      iconLocalPath: data.iconLocalPath,
      feelsLike: data.feelsLike,
      pressure: data.pressure,
      humidity: data.humidity,
      windSpeed: data.windSpeed,
      visibility: data.visibility,
      sunRise: data.sunRise,
      sunSet: data.sunSet,
      currentDayHigh: data.currentDayHigh,
      currentDayLow: data.currentDayLow,
      forecast: data.forecast,
      isLoaded: true,
    }),

  toggleWeatherView: () =>
    set(state => ({showDetailedWeather: !state.showDetailedWeather})),

  clearWeather: () =>
    set({
      temperature: '--°',
      city: '',
      forecast: [],
      isLoaded: false,
    }),
}));
