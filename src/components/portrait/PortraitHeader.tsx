import React, {useState, useEffect} from 'react';
import {View, Text, Image, StyleSheet} from 'react-native';
import {useWeatherStore} from '../../store/weatherStore';
import {useSiteLogoStore} from '../../store/siteLogoStore';

/**
 * Portrait header - mirrors PortraitHeaderView.swift
 * Compact header with logo, time, and weather summary.
 */
export function PortraitHeader({fontColor = '#FFFFFF'}: {fontColor?: string}) {
  const {temperature, iconLocalPath, city} = useWeatherStore();
  const {logoLocalPath} = useSiteLogoStore();
  const [currentTime, setCurrentTime] = useState('');
  const [currentDate, setCurrentDate] = useState('');

  useEffect(() => {
    const updateTime = () => {
      const now = new Date();
      setCurrentTime(
        now.toLocaleTimeString('en-US', {
          hour: '2-digit',
          minute: '2-digit',
          hour12: true,
        })
      );
      setCurrentDate(
        now.toLocaleDateString('en-US', {
          weekday: 'short',
          month: 'short',
          day: 'numeric',
        })
      );
    };
    updateTime();
    const timer = setInterval(updateTime, 1000);
    return () => clearInterval(timer);
  }, []);

  return (
    <View style={styles.container}>
      {logoLocalPath ? (
        <Image
          source={{uri: logoLocalPath}}
          style={styles.logo}
          resizeMode="contain"
        />
      ) : (
        <View style={styles.logoPlaceholder} />
      )}

      <View style={styles.timeBlock}>
        <Text style={[styles.time, {color: fontColor}]}>{currentTime}</Text>
        <Text style={[styles.date, {color: fontColor}]}>{currentDate}</Text>
      </View>

      <View style={styles.weatherBlock}>
        {iconLocalPath ? (
          <Image
            source={{uri: iconLocalPath}}
            style={styles.weatherIcon}
            resizeMode="contain"
          />
        ) : null}
        <Text style={[styles.temp, {color: fontColor}]}>{temperature}</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 12,
    paddingVertical: 8,
    backgroundColor: 'rgba(0,0,0,0.7)',
    height: 56,
  },
  logo: {
    width: 60,
    height: 36,
  },
  logoPlaceholder: {
    width: 60,
    height: 36,
  },
  timeBlock: {
    alignItems: 'center',
  },
  time: {
    fontSize: 18,
    fontWeight: 'bold',
    fontFamily: 'Poppins-Bold',
  },
  date: {
    fontSize: 11,
    fontFamily: 'Poppins-Regular',
  },
  weatherBlock: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  weatherIcon: {
    width: 28,
    height: 28,
  },
  temp: {
    fontSize: 18,
    fontWeight: 'bold',
    fontFamily: 'Poppins-Bold',
  },
});
