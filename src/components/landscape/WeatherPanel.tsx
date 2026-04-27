import React from 'react';
import {View, Text, Image, StyleSheet, ScrollView} from 'react-native';
import {useWeatherStore} from '../../store/weatherStore';

/**
 * Detailed weather panel for landscape UI Type 1.
 * Toggles between detailed view and 4-day forecast.
 * Mirrors DetailedWeatherTableViewCell + FourDayWeatherTableCell.
 */
export function WeatherPanel({fontColor = '#FFFFFF'}: {fontColor?: string}) {
  const {
    showDetailedWeather,
    temperature,
    feelsLike,
    humidity,
    pressure,
    windSpeed,
    visibility,
    sunRise,
    sunSet,
    currentDayHigh,
    currentDayLow,
    temperatureText,
    forecast,
    iconLocalPath,
  } = useWeatherStore();

  if (showDetailedWeather) {
    return (
      <View style={styles.container}>
        <View style={styles.currentWeatherRow}>
          {iconLocalPath ? (
            <Image
              source={{uri: iconLocalPath}}
              style={styles.weatherIconLarge}
              resizeMode="contain"
            />
          ) : null}
          <View>
            <Text style={[styles.tempLarge, {color: fontColor}]}>
              {temperature}
            </Text>
            <Text style={[styles.tempText, {color: fontColor}]}>
              {temperatureText}
            </Text>
          </View>
        </View>

        <View style={styles.detailsGrid}>
          <WeatherRow label="Feels Like" value={feelsLike} color={fontColor} />
          <WeatherRow label="Humidity" value={humidity} color={fontColor} />
          <WeatherRow label="Pressure" value={pressure} color={fontColor} />
          <WeatherRow label="Wind" value={windSpeed} color={fontColor} />
          <WeatherRow label="Visibility" value={visibility} color={fontColor} />
          <WeatherRow label="High/Low" value={`${currentDayHigh}/${currentDayLow}`} color={fontColor} />
          <WeatherRow label="Sunrise" value={sunRise} color={fontColor} />
          <WeatherRow label="Sunset" value={sunSet} color={fontColor} />
        </View>
      </View>
    );
  }

  // 4-day forecast view
  return (
    <View style={styles.container}>
      {forecast.slice(0, 4).map((day, index) => (
        <View key={index} style={styles.forecastRow}>
          <Text style={[styles.forecastDay, {color: fontColor}]}>{day.day}</Text>
          {day.iconLocalPath ? (
            <Image
              source={{uri: day.iconLocalPath}}
              style={styles.forecastIcon}
              resizeMode="contain"
            />
          ) : (
            <View style={styles.forecastIcon} />
          )}
          <Text style={[styles.forecastText, {color: fontColor}]}>
            {day.weatherText}
          </Text>
          <Text style={[styles.forecastTemp, {color: fontColor}]}>
            {day.high}/{day.low}
          </Text>
        </View>
      ))}
    </View>
  );
}

function WeatherRow({
  label,
  value,
  color,
}: {
  label: string;
  value: string;
  color: string;
}) {
  return (
    <View style={styles.weatherRow}>
      <Text style={[styles.weatherLabel, {color}]}>{label}</Text>
      <Text style={[styles.weatherValue, {color}]}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 12,
  },
  currentWeatherRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 16,
    gap: 12,
  },
  weatherIconLarge: {
    width: 64,
    height: 64,
  },
  tempLarge: {
    fontSize: 42,
    fontWeight: 'bold',
    fontFamily: 'Poppins-Bold',
  },
  tempText: {
    fontSize: 16,
    fontFamily: 'Poppins-Regular',
  },
  detailsGrid: {
    gap: 6,
  },
  weatherRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 2,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: 'rgba(255,255,255,0.2)',
  },
  weatherLabel: {
    fontSize: 14,
    fontFamily: 'Poppins-Regular',
  },
  weatherValue: {
    fontSize: 14,
    fontWeight: '500',
    fontFamily: 'Poppins-Medium',
  },
  forecastRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 8,
    gap: 8,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: 'rgba(255,255,255,0.2)',
  },
  forecastDay: {
    width: 60,
    fontSize: 15,
    fontFamily: 'Poppins-Regular',
  },
  forecastIcon: {
    width: 36,
    height: 36,
  },
  forecastText: {
    flex: 1,
    fontSize: 14,
    fontFamily: 'Poppins-Regular',
  },
  forecastTemp: {
    fontSize: 15,
    fontWeight: '500',
    fontFamily: 'Poppins-Medium',
  },
});
