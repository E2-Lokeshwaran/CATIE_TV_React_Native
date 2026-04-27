import React from 'react';
import {View, StyleSheet} from 'react-native';
import {Header} from '../shared/Header';
import {CarouselView} from '../shared/CarouselView';
import {ScrollTextTicker} from '../shared/ScrollTextTicker';
import {StatusIndicatorList} from './StatusIndicatorList';

interface LandscapeType2Props {
  fontColor?: string;
}

/**
 * UI Type 2: Landscape Clock-Focused Display
 * No events, date/time focus. Has status indicators.
 * Carousel: 16:9
 */
export function LandscapeType2({fontColor = '#FFFFFF'}: LandscapeType2Props) {
  return (
    <View style={styles.container}>
      <Header fontColor={fontColor} />

      <View style={styles.contentRow}>
        {/* Status indicators on left */}
        <View style={styles.leftColumn}>
          <StatusIndicatorList fontColor={fontColor} />
        </View>

        {/* Carousel fills remaining space */}
        <View style={styles.carouselContainer}>
          <CarouselView uiType={2} style={styles.carousel} />
        </View>
      </View>

      <ScrollTextTicker fontColor={fontColor} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
  },
  contentRow: {
    flex: 1,
    flexDirection: 'row',
  },
  leftColumn: {
    width: '22%',
    borderRightWidth: 1,
    borderRightColor: 'rgba(255,255,255,0.1)',
    padding: 8,
  },
  carouselContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  carousel: {
    width: '100%',
  },
});
