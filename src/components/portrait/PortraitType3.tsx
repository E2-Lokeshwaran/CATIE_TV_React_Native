import React, {useState, useEffect} from 'react';
import {View, StyleSheet} from 'react-native';
import {PortraitHeader} from './PortraitHeader';
import {PortraitFooter} from './PortraitFooter';
import {CarouselView} from '../shared/CarouselView';
import {PortraitWeatherView} from './PortraitWeatherView';
import {PortraitEventsView} from './PortraitEventsView';
import {PortraitStatusIndicatorView} from './PortraitStatusIndicatorView';
import {useEventsStore} from '../../store/eventsStore';

interface PortraitType3Props {
  fontColor?: string;
  accentColor?: string;
}

/**
 * UI Type 3: Portrait Full Content
 * Shows weather/events/status + portrait carousel
 * Mirrors PortraitMainContentView.swift + PortraitView.swift
 */
export function PortraitType3({
  fontColor = '#FFFFFF',
  accentColor = '#3773b3',
}: PortraitType3Props) {
  const {hasEvents} = useEventsStore();
  const [showingEvents, setShowingEvents] = useState(true);

  // Toggle between events/status and weather every 15s
  useEffect(() => {
    if (!hasEvents) {
      setShowingEvents(false);
      return;
    }
    setShowingEvents(true);
    const timer = setInterval(() => {
      setShowingEvents(prev => !prev);
    }, 15000);
    return () => clearInterval(timer);
  }, [hasEvents]);

  return (
    <View style={styles.container}>
      <PortraitHeader fontColor={fontColor} />

      <View style={styles.content}>
        {/* Left content area: toggles weather/events */}
        <View style={styles.sideContent}>
          {showingEvents ? (
            <>
              <PortraitEventsView fontColor={fontColor} accentColor={accentColor} />
              <PortraitStatusIndicatorView fontColor={fontColor} />
            </>
          ) : (
            <PortraitWeatherView fontColor={fontColor} />
          )}
        </View>

        {/* Carousel */}
        <CarouselView uiType={3} style={styles.carousel} />
      </View>

      <PortraitFooter fontColor={fontColor} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
  },
  content: {
    flex: 1,
    flexDirection: 'column',
  },
  sideContent: {
    flex: 1,
    padding: 10,
  },
  carousel: {
    width: '100%',
  },
});
