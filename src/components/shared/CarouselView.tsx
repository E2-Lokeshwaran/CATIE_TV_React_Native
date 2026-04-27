import React from 'react';
import {View, Image, StyleSheet, Dimensions} from 'react-native';
import {useCarouselStore} from '../../store/carouselStore';
import {getCarouselAspectRatio} from '../../constants/uiTypes';

interface CarouselViewProps {
  uiType: number;
  style?: object;
}

/**
 * Carousel image display component.
 * Mirrors the carousel UIImageView behavior.
 * Aspect ratios from AGENTS.md:
 * - UI Type 1,2: 16:9
 * - UI Type 3,6: 9:16
 * - UI Type 4: 1:1
 * - UI Type 5: 21:9
 */
export function CarouselView({uiType, style}: CarouselViewProps) {
  const currentSlide = useCarouselStore(s => s.currentSlide);

  const aspectRatio = getCarouselAspectRatio(uiType);

  return (
    <View style={[styles.container, {aspectRatio}, style]}>
      {currentSlide?.imageLocalPath ? (
        <Image
          source={{uri: currentSlide.imageLocalPath}}
          style={styles.image}
          resizeMode="cover"
        />
      ) : (
        <View style={styles.placeholder} />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    overflow: 'hidden',
    backgroundColor: '#000',
  },
  image: {
    width: '100%',
    height: '100%',
  },
  placeholder: {
    flex: 1,
    backgroundColor: '#111',
  },
});
