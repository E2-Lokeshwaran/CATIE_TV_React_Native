import React from 'react';
import {View, Text, Image, StyleSheet} from 'react-native';
import {useWeatherStore} from '../../store/weatherStore';

/**
 * Portrait weather display - mirrors PortraitWeatherView.swift
 */
export function PortraitWeatherView({
  fontColor = '#FFFFFF',
}: {
  fontColor?: string;
}) {
  const {temperature, city, temperatureText, iconLocalPath, feelsLike, humidity} =
    useWeatherStore();

  return (
    <View style={styles.container}>
      <View style={styles.mainRow}>
        {iconLocalPath ? (
          <Image
            source={{uri: iconLocalPath}}
            style={styles.icon}
            resizeMode="contain"
          />
        ) : null}
        <View>
          <Text style={[styles.temp, {color: fontColor}]}>{temperature}</Text>
          <Text style={[styles.desc, {color: fontColor}]}>{temperatureText}</Text>
          <Text style={[styles.city, {color: fontColor}]}>{city}</Text>
        </View>
      </View>
      <View style={styles.details}>
        <Text style={[styles.detailText, {color: fontColor}]}>
          Feels like: {feelsLike}
        </Text>
        <Text style={[styles.detailText, {color: fontColor}]}>
          Humidity: {humidity}
        </Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    padding: 12,
    backgroundColor: 'rgba(255,255,255,0.08)',
    borderRadius: 8,
  },
  mainRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    marginBottom: 8,
  },
  icon: {
    width: 56,
    height: 56,
  },
  temp: {
    fontSize: 36,
    fontWeight: 'bold',
    fontFamily: 'Poppins-Bold',
  },
  desc: {
    fontSize: 14,
    fontFamily: 'Poppins-Regular',
  },
  city: {
    fontSize: 13,
    fontFamily: 'Poppins-Regular',
  },
  details: {
    flexDirection: 'row',
    gap: 16,
  },
  detailText: {
    fontSize: 13,
    fontFamily: 'Poppins-Regular',
  },
});
