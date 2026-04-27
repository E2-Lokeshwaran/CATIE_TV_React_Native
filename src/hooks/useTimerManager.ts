import {useEffect, useRef, useCallback} from 'react';
import {useCarouselStore} from '../store/carouselStore';
import {useWeatherStore} from '../store/weatherStore';
import {useEventsStore} from '../store/eventsStore';
import {useStatusIndicatorStore} from '../store/statusIndicatorStore';
import {useSaraAlertStore} from '../store/saraAlertStore';
import {AudioService} from '../services/audio/AudioService';

/**
 * Centralized timer management.
 * Mirrors the 10+ timers in MainScreenViewController.
 *
 * Timer activation rules per AGENTS.md:
 * - Carousel timer: always active
 * - Time timer: always active
 * - SARA flash timer: always when sara is present
 * - Event animation (15s): UI type 1 only
 * - Ongoing event schedule: UI types 1, 3
 * - Status animation (10s): UI types 1, 2 (landscape)
 * - Weather display (10s): UI type 1 only when no events
 * - Scrollbar (4s): Landscape only (1, 2, 5)
 * - Radio resume (60s): 1-4 always, 5-6 only if tvRadioFlag=1
 */
export function useTimerManager(uiType: number, tvRadioFlag: number) {
  const advanceCarousel = useCarouselStore(
    s => s.advanceToNextSlideWithAdvertisements
  );
  const currentSlide = useCarouselStore(s => s.currentSlide);
  const globalSlotTime = useCarouselStore(s => s.globalSlotTime);
  const toggleWeatherView = useWeatherStore(s => s.toggleWeatherView);
  const hasEvents = useEventsStore(s => s.hasEvents);
  const nextStatusPage = useStatusIndicatorStore(s => s.nextPage);
  const isSaraPresent = useSaraAlertStore(s => s.isPresent);
  const saraFlash = useSaraAlertStore(s => s.flash);
  const saraFlashColor = useSaraAlertStore(s => s.flashColor);
  const saraBorderColor = useSaraAlertStore(s => s.borderColor);

  // Sara flash state for UI
  const saraFlashVisible = useRef(true);
  const saraFlashTimer = useRef<ReturnType<typeof setInterval> | null>(null);

  // --- Carousel Timer (always active) ---
  const carouselTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const scheduleNextSlide = useCallback(() => {
    if (carouselTimer.current) {
      clearTimeout(carouselTimer.current);
    }

    const slide = currentSlide;
    const interval = (slide?.slotTime ?? globalSlotTime ?? 5) * 1000;

    carouselTimer.current = setTimeout(async () => {
      // Check if narration should play for this slide
      if (slide?.audioFlag && slide?.audioPath) {
        await AudioService.playNarration(
          slide.audioPath,
          durationSec => {
            // Use audio duration as next slide interval
            if (carouselTimer.current) {
              clearTimeout(carouselTimer.current);
            }
            carouselTimer.current = setTimeout(() => {
              advanceCarousel();
            }, durationSec * 1000);
          },
          () => {
            // Narration ended - advance normally
            advanceCarousel();
          }
        );
      } else {
        advanceCarousel();
      }
    }, interval);
  }, [currentSlide, globalSlotTime, advanceCarousel]);

  useEffect(() => {
    scheduleNextSlide();
    return () => {
      if (carouselTimer.current) {
        clearTimeout(carouselTimer.current);
      }
    };
  }, [currentSlide, scheduleNextSlide]);

  // --- Status Indicator Animation (10s) - UI types 1, 2 only ---
  useEffect(() => {
    if (uiType !== 1 && uiType !== 2) {
      return;
    }
    const timer = setInterval(() => {
      nextStatusPage();
    }, 10000);

    return () => clearInterval(timer);
  }, [uiType, nextStatusPage]);

  // --- Weather Display Timer (10s) - UI type 1 only, when no events ---
  useEffect(() => {
    if (uiType !== 1 || hasEvents) {
      return;
    }
    const timer = setInterval(() => {
      toggleWeatherView();
    }, 10000);

    return () => clearInterval(timer);
  }, [uiType, hasEvents, toggleWeatherView]);

  // --- SARA Alert Flash Timer (always when present) ---
  useEffect(() => {
    if (!isSaraPresent || saraFlash !== 1) {
      if (saraFlashTimer.current) {
        clearInterval(saraFlashTimer.current);
        saraFlashTimer.current = null;
      }
      return;
    }

    saraFlashTimer.current = setInterval(() => {
      saraFlashVisible.current = !saraFlashVisible.current;
    }, 500);

    return () => {
      if (saraFlashTimer.current) {
        clearInterval(saraFlashTimer.current);
      }
    };
  }, [isSaraPresent, saraFlash]);

  // --- Radio Resume Timer (60s) ---
  useEffect(() => {
    const shouldEnableRadioTimer =
      uiType <= 4 || (uiType >= 5 && tvRadioFlag === 1);
    if (!shouldEnableRadioTimer) {
      return;
    }

    const timer = setInterval(() => {
      if (
        AudioService.getCurrentPriority() === null ||
        AudioService.getCurrentPriority() === 'radio'
      ) {
        AudioService.resumeRadio();
      }
    }, 60000);

    return () => clearInterval(timer);
  }, [uiType, tvRadioFlag]);

  return {saraFlashVisible};
}
