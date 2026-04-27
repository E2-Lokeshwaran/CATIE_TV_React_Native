import React, {useState, useEffect} from 'react';
import {View, Text, Image, StyleSheet} from 'react-native';
import {useWeatherStore} from '../../store/weatherStore';
import {useSiteLogoStore} from '../../store/siteLogoStore';
import {useAppStore} from '../../store/appStore';

interface HeaderProps {
  showRadioIcon?: boolean;
  fontColor?: string;
}

/**
 * Shared header component.
 * Mirrors landscape header + PortraitHeaderView.swift.
 *
 * Displays: SiteLogo | Time/Date | Weather temp + icon
 */
export function Header({showRadioIcon = true, fontColor = '#FFFFFF'}: HeaderProps) {
  const {temperature, city, iconLocalPath} = useWeatherStore();
  const {logoLocalPath} = useSiteLogoStore();
  const {isWsConnected} = useAppStore();

  const [currentTime, setCurrentTime] = useState('');
  const [currentDate, setCurrentDate] = useState('');

  useEffect(() => {
    const updateTime = () => {
      const now = new Date();
      const timeStr = now.toLocaleTimeString('en-US', {
        hour: '2-digit',
        minute: '2-digit',
        hour12: true,
      });
      const dateStr = now.toLocaleDateString('en-US', {
        weekday: 'short',
        month: 'short',
        day: 'numeric',
      });
      setCurrentTime(timeStr);
      setCurrentDate(dateStr);
    };

    updateTime();
    const timer = setInterval(updateTime, 1000);
    return () => clearInterval(timer);
  }, []);

  return (
    <View style={styles.container}>
      {/* Site Logo */}
      <View style={styles.logoContainer}>
        {logoLocalPath ? (
          <Image
            source={{uri: logoLocalPath}}
            style={styles.logo}
            resizeMode="contain"
          />
        ) : (
          <View style={styles.logoPlaceholder} />
        )}
      </View>

      {/* Connection Status Indicator */}
      <View
        style={[
          styles.connectionDot,
          {backgroundColor: isWsConnected ? '#00FF00' : '#FF0000'},
        ]}
      />

      {/* Time and Date */}
      <View style={styles.timeContainer}>
        <Text style={[styles.timeText, {color: fontColor}]}>{currentTime}</Text>
        <Text style={[styles.dateText, {color: fontColor}]}>{currentDate}</Text>
      </View>

      {/* Weather Summary */}
      <View style={styles.weatherContainer}>
        {iconLocalPath ? (
          <Image
            source={{uri: iconLocalPath}}
            style={styles.weatherIcon}
            resizeMode="contain"
          />
        ) : null}
        <Text style={[styles.temperatureText, {color: fontColor}]}>
          {temperature}
        </Text>
        {city ? (
          <Text style={[styles.cityText, {color: fontColor}]}>{city}</Text>
        ) : null}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 8,
    backgroundColor: 'rgba(0,0,0,0.6)',
    height: 60,
  },
  logoContainer: {
    width: 80,
    height: 44,
    justifyContent: 'center',
  },
  logo: {
    width: 80,
    height: 44,
  },
  logoPlaceholder: {
    width: 80,
    height: 44,
  },
  connectionDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
    marginLeft: 8,
  },
  timeContainer: {
    flex: 1,
    alignItems: 'center',
  },
  timeText: {
    fontSize: 22,
    fontWeight: 'bold',
  },
  dateText: {
    fontSize: 14,
  },
  weatherContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  weatherIcon: {
    width: 36,
    height: 36,
  },
  temperatureText: {
    fontSize: 20,
    fontWeight: 'bold',
  },
  cityText: {
    fontSize: 13,
  },
});
