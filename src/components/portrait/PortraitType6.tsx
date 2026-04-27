import React from 'react';
import {View, StyleSheet} from 'react-native';
import {PortraitFooter} from './PortraitFooter';
import {CarouselView} from '../shared/CarouselView';

/**
 * UI Type 6: Portrait Carousel Padded (9:16)
 * No header, padded carousel + footer
 * Radio only if tvRadioFlag=1 (handled by orchestrator)
 */
export function PortraitType6({fontColor = '#FFFFFF'}: {fontColor?: string}) {
  return (
    <View style={styles.container}>
      <View style={styles.carouselArea}>
        <CarouselView uiType={6} style={styles.carousel} />
      </View>
      <PortraitFooter fontColor={fontColor} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
    alignItems: 'center',
  },
  carouselArea: {
    flex: 1,
    justifyContent: 'center',
    padding: 16,
    width: '100%',
    alignItems: 'center',
  },
  carousel: {
    flex: 1,
  },
});
