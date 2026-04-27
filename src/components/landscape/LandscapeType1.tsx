import React from 'react';
import {View, StyleSheet} from 'react-native';
import {Header} from '../shared/Header';
import {CarouselView} from '../shared/CarouselView';
import {ScrollTextTicker} from '../shared/ScrollTextTicker';
import {WeatherPanel} from './WeatherPanel';
import {EventsList} from './EventsList';
import {StatusIndicatorList} from './StatusIndicatorList';

interface LandscapeType1Props {
  fontColor?: string;
}

/**
 * UI Type 1: Landscape Full Content Layout
 * Layout: Header | [Left: Weather+Events | Carousel | Right: Status] | Footer: ScrollText
 *
 * - Weather: conditional (shows when no events)
 * - Events: always shown when available
 * - Status Indicators: right column, cycling
 * - Carousel: 16:9 center
 */
export function LandscapeType1({fontColor = '#FFFFFF'}: LandscapeType1Props) {
  return (
    <View style={styles.container}>
      <Header fontColor={fontColor} />

      <View style={styles.contentRow}>
        {/* Left column: Weather/Events */}
        <View style={styles.leftColumn}>
          <WeatherPanel fontColor={fontColor} />
          <EventsList fontColor={fontColor} />
        </View>

        {/* Center: Carousel */}
        <View style={styles.carouselContainer}>
          <CarouselView uiType={1} style={styles.carousel} />
        </View>

        {/* Right column: Status Indicators */}
        <View style={styles.rightColumn}>
          <StatusIndicatorList fontColor={fontColor} />
        </View>
      </View>

      {/* Footer: Scrolling text */}
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
  rightColumn: {
    width: '22%',
    borderLeftWidth: 1,
    borderLeftColor: 'rgba(255,255,255,0.1)',
    padding: 8,
  },
});
