import React, {useState, useEffect} from 'react';
import {View, Text, StyleSheet} from 'react-native';
import {useClockStore} from '../../store/clockStore';

/**
 * Full-screen clock overlay.
 * Mirrors ClockView.swift + PortraitClockView.swift.
 * Shows when clockStore.isClockPresented is true.
 */
export function ClockOverlay() {
  const {isClockPresented, clockMessage} = useClockStore();
  const [currentTime, setCurrentTime] = useState('');
  const [currentDate, setCurrentDate] = useState('');

  useEffect(() => {
    if (!isClockPresented) {
      return;
    }

    const updateTime = () => {
      const now = new Date();
      setCurrentTime(
        now.toLocaleTimeString('en-US', {
          hour: '2-digit',
          minute: '2-digit',
          second: '2-digit',
          hour12: true,
        })
      );
      setCurrentDate(
        now.toLocaleDateString('en-US', {
          weekday: 'long',
          year: 'numeric',
          month: 'long',
          day: 'numeric',
        })
      );
    };

    updateTime();
    const timer = setInterval(updateTime, 1000);
    return () => clearInterval(timer);
  }, [isClockPresented]);

  if (!isClockPresented) {
    return null;
  }

  return (
    <View style={StyleSheet.absoluteFillObject}>
      <View style={styles.container}>
        <Text style={styles.timeText}>{currentTime}</Text>
        <Text style={styles.dateText}>{currentDate}</Text>
        {clockMessage ? (
          <Text style={styles.messageText}>{clockMessage}</Text>
        ) : null}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
    alignItems: 'center',
    justifyContent: 'center',
  },
  timeText: {
    fontSize: 96,
    fontWeight: 'bold',
    color: '#FFFFFF',
    fontFamily: 'Poppins-Bold',
  },
  dateText: {
    fontSize: 32,
    color: '#CCCCCC',
    fontFamily: 'Poppins-Regular',
    marginTop: 16,
  },
  messageText: {
    fontSize: 24,
    color: '#AAAAAA',
    fontFamily: 'Poppins-Regular',
    marginTop: 24,
    textAlign: 'center',
    paddingHorizontal: 40,
  },
});
