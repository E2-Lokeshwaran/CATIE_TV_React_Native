import React from 'react';
import {View, StyleSheet} from 'react-native';
import {PortraitHeader} from './PortraitHeader';
import {PortraitFooter} from './PortraitFooter';
import {CarouselView} from '../shared/CarouselView';

/**
 * UI Type 4: Portrait Full-Screen Carousel
 * Header + full content area carousel + footer
 * No events, no status indicators
 */
export function PortraitType4({fontColor = '#FFFFFF'}: {fontColor?: string}) {
  return (
    <View style={styles.container}>
      <PortraitHeader fontColor={fontColor} />
      <View style={styles.carouselArea}>
        <CarouselView uiType={4} style={styles.carousel} />
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
  carouselArea: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  carousel: {
    width: '100%',
    height: '100%',
  },
});
