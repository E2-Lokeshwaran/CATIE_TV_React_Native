import React, {useCallback, useEffect, useRef} from 'react';
import {ScrollView, View, LayoutChangeEvent, StyleSheet} from 'react-native';

interface AutoScrollingViewProps {
  /**
   * How long (ms) the scroll-to-bottom animation takes.
   * Maps to scrollDuration in Swift AutoScrollingScrollView.
   */
  scrollDuration?: number;
  /**
   * Delay (ms) before starting the first scroll.
   * Maps to scrollDelay in Swift.
   */
  scrollDelay?: number;
  /**
   * If true, after reaching the bottom the view resets to top and scrolls again.
   * Maps to continuousScrolling in Swift.
   */
  continuousScrolling?: boolean;
  /**
   * Pause (ms) at the bottom before resetting in continuous mode.
   * Swift uses 2000ms.
   */
  bottomPauseDuration?: number;
  /**
   * Called when a scroll cycle completes (bottom reached).
   * Maps to onScrollComplete in Swift.
   */
  onScrollComplete?: () => void;
  children: React.ReactNode;
  style?: object;
}

/**
 * AutoScrollingView - React Native port of AutoScrollingScrollView.swift
 *
 * Behaviour:
 * 1. Measures content height vs viewport height.
 * 2. If content fits, waits scrollDuration ms then calls onScrollComplete.
 * 3. If content overflows, animates scroll to bottom over scrollDuration ms.
 * 4. In continuous mode: pauses 2s at bottom → resets to top → repeats.
 * 5. In non-continuous mode: calls onScrollComplete once at bottom and stops.
 */
export function AutoScrollingView({
  scrollDuration = 15000,
  scrollDelay = 0,
  continuousScrolling = false,
  bottomPauseDuration = 2000,
  onScrollComplete,
  children,
  style,
}: AutoScrollingViewProps) {
  const scrollRef = useRef<ScrollView>(null);
  const contentHeight = useRef(0);
  const viewportHeight = useRef(0);
  const isAnimating = useRef(false);
  const didComplete = useRef(false);
  const delayTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const resetTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const cancelAll = useCallback(() => {
    if (delayTimerRef.current) {
      clearTimeout(delayTimerRef.current);
      delayTimerRef.current = null;
    }
    if (resetTimerRef.current) {
      clearTimeout(resetTimerRef.current);
      resetTimerRef.current = null;
    }
    isAnimating.current = false;
    didComplete.current = false;
  }, []);

  const doScrollCycle = useCallback(() => {
    if (isAnimating.current) return;
    const scrollable = contentHeight.current - viewportHeight.current;
    if (scrollable <= 0) {
      // Content fits — wait then call completion
      delayTimerRef.current = setTimeout(() => {
        onScrollComplete?.();
      }, scrollDuration);
      return;
    }

    isAnimating.current = true;

    scrollRef.current?.scrollTo({y: scrollable, animated: true});

    // After scrollDuration ms the animation should be done
    delayTimerRef.current = setTimeout(() => {
      isAnimating.current = false;
      onScrollComplete?.();

      if (continuousScrolling) {
        // Pause at bottom then reset
        resetTimerRef.current = setTimeout(() => {
          scrollRef.current?.scrollTo({y: 0, animated: false});
          // Small settle delay before next cycle
          resetTimerRef.current = setTimeout(() => {
            didComplete.current = false;
            doScrollCycle();
          }, 500);
        }, bottomPauseDuration);
      } else {
        didComplete.current = true;
      }
    }, scrollDuration);
  }, [scrollDuration, continuousScrolling, bottomPauseDuration, onScrollComplete]);

  const startScrolling = useCallback(() => {
    if (didComplete.current && !continuousScrolling) return;
    cancelAll();

    if (scrollDelay > 0) {
      delayTimerRef.current = setTimeout(doScrollCycle, scrollDelay);
    } else {
      doScrollCycle();
    }
  }, [scrollDelay, continuousScrolling, cancelAll, doScrollCycle]);

  const onContentLayout = useCallback(
    (e: LayoutChangeEvent) => {
      const newContentHeight = e.nativeEvent.layout.height;
      if (Math.abs(newContentHeight - contentHeight.current) < 2) return;
      contentHeight.current = newContentHeight;
      // Re-evaluate scrolling when content size changes
      if (viewportHeight.current > 0) {
        cancelAll();
        startScrolling();
      }
    },
    [cancelAll, startScrolling],
  );

  const onViewportLayout = useCallback(
    (e: LayoutChangeEvent) => {
      viewportHeight.current = e.nativeEvent.layout.height;
      if (contentHeight.current > 0) {
        startScrolling();
      }
    },
    [startScrolling],
  );

  // Clean up on unmount
  useEffect(() => {
    return () => {
      cancelAll();
    };
  }, [cancelAll]);

  return (
    <View style={[styles.container, style]} onLayout={onViewportLayout}>
      <ScrollView
        ref={scrollRef}
        scrollEnabled={false}
        showsVerticalScrollIndicator={false}
        bounces={false}
        overScrollMode="never">
        <View onLayout={onContentLayout}>{children}</View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    overflow: 'hidden',
  },
});
