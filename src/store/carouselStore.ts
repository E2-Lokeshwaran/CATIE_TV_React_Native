import {create} from 'zustand';
import {CarouselSlide} from '../types/carousel.types';

interface CarouselState {
  normalSlides: CarouselSlide[];
  adSlides: CarouselSlide[];
  currentSlide: CarouselSlide | null;
  currentIndex: number;
  normalIndex: number;
  normalSlideCount: number;
  advertisementIndex: number;
  globalSlotTime: number;
  isLoaded: boolean;
}

interface CarouselActions {
  setSlides: (
    normalSlides: CarouselSlide[],
    adSlides: CarouselSlide[],
    globalSlotTime: number
  ) => void;
  setCurrentSlide: (slide: CarouselSlide) => void;
  advanceToNextSlideWithAdvertisements: () => CarouselSlide | null;
  clearSlides: () => void;
}

export const useCarouselStore = create<CarouselState & CarouselActions>(
  (set, get) => ({
    normalSlides: [],
    adSlides: [],
    currentSlide: null,
    currentIndex: 0,
    normalIndex: 0,
    normalSlideCount: 0,
    advertisementIndex: 0,
    globalSlotTime: 5,
    isLoaded: false,

    setSlides: (normalSlides, adSlides, globalSlotTime) => {
      const firstSlide = normalSlides.length > 0 ? normalSlides[0] : null;
      set({
        normalSlides,
        adSlides,
        globalSlotTime,
        currentSlide: firstSlide,
        normalIndex: 0,
        normalSlideCount: 0,
        advertisementIndex: 0,
        isLoaded: true,
      });
    },

    setCurrentSlide: slide => set({currentSlide: slide}),

    // Port of advanceToNextSlideWithAdvertisements() from Swift
    // Rule: after every 4 normal slides, show 1 ad slide
    advanceToNextSlideWithAdvertisements: () => {
      const state = get();
      const {
        normalSlides,
        adSlides,
        normalIndex,
        normalSlideCount,
        advertisementIndex,
      } = state;

      if (normalSlides.length === 0) {
        return null;
      }

      let nextSlide: CarouselSlide;
      let nextNormalIndex = normalIndex;
      let nextNormalSlideCount = normalSlideCount;
      let nextAdIndex = advertisementIndex;

      // After every 4 normal slides, show an ad if available
      if (
        nextNormalSlideCount > 0 &&
        nextNormalSlideCount % 4 === 0 &&
        adSlides.length > 0
      ) {
        nextSlide = adSlides[nextAdIndex % adSlides.length];
        nextAdIndex = (nextAdIndex + 1) % adSlides.length || 0;
        // Don't increment normal index for ad slides
      } else {
        nextSlide = normalSlides[nextNormalIndex];
        nextNormalIndex = (nextNormalIndex + 1) % normalSlides.length;
        nextNormalSlideCount += 1;
      }

      set({
        currentSlide: nextSlide,
        normalIndex: nextNormalIndex,
        normalSlideCount: nextNormalSlideCount,
        advertisementIndex: nextAdIndex,
      });

      return nextSlide;
    },

    clearSlides: () =>
      set({
        normalSlides: [],
        adSlides: [],
        currentSlide: null,
        normalIndex: 0,
        normalSlideCount: 0,
        advertisementIndex: 0,
        isLoaded: false,
      }),
  })
);
