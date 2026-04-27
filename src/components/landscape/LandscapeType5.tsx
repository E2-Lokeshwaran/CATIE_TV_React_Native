import React from 'react';
import {View, StyleSheet} from 'react-native';
import {Header} from '../shared/Header';
import {CarouselView} from '../shared/CarouselView';
import {ScrollTextTicker} from '../shared/ScrollTextTicker';
import {useAppStore} from '../../store/appStore';

interface LandscapeType5Props {
  fontColor?: string;
}

/**
 * UI Type 5: Landscape Carousel-Only Wide (21:9)
 * No events, no status indicators.
 * Radio only if tvRadioFlag=1.
 */
export function LandscapeType5({fontColor = '#FFFFFF'}: LandscapeType5Props) {
  const {tvRadioFlag} = useAppStore();

  return (
    <View style={styles.container}>
      <Header showRadioIcon={tvRadioFlag === 1} fontColor={fontColor} />

      {/* Full-width carousel */}
      <View style={styles.carouselContainer}>
        <CarouselView uiType={5} style={styles.carousel} />
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
  carouselContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  carousel: {
    width: '100%',
  },
});
