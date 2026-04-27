import React, {useEffect, useRef} from 'react';
import {View, Text, Animated, StyleSheet, Dimensions} from 'react-native';
import {useScrollMessageStore} from '../../store/scrollMessageStore';

const SCREEN_WIDTH = Dimensions.get('window').width;
const SCROLL_SPEED = 80; // pixels per second

/**
 * Continuous horizontal scrolling ticker.
 * Mirrors the scrollbarTimer + contentOffset animation in
 * MainScreenViewControllerExtension.swift.
 *
 * Text is doubled to create seamless circular loop.
 */
export function ScrollTextTicker({
  fontColor = '#FFFFFF',
  backgroundColor = 'rgba(0,0,0,0.7)',
}: {
  fontColor?: string;
  backgroundColor?: string;
}) {
  const {message, isLoaded} = useScrollMessageStore();
  const scrollX = useRef(new Animated.Value(0)).current;
  const animRef = useRef<Animated.CompositeAnimation | null>(null);
  const textWidth = useRef(0);

  const displayText = message ? `${message}     ${message}` : '';

  useEffect(() => {
    if (!isLoaded || !message) {
      return;
    }

    if (textWidth.current === 0) {
      return;
    }

    const duration = (textWidth.current / 2 / SCROLL_SPEED) * 1000;

    scrollX.setValue(0);
    animRef.current = Animated.loop(
      Animated.timing(scrollX, {
        toValue: -textWidth.current / 2,
        duration,
        useNativeDriver: true,
      })
    );
    animRef.current.start();

    return () => {
      animRef.current?.stop();
    };
  }, [message, isLoaded, scrollX]);

  if (!isLoaded || !message) {
    return null;
  }

  return (
    <View style={[styles.container, {backgroundColor}]}>
      <Animated.Text
        style={[
          styles.text,
          {color: fontColor, transform: [{translateX: scrollX}]},
        ]}
        numberOfLines={1}
        onLayout={e => {
          textWidth.current = e.nativeEvent.layout.width;
        }}>
        {displayText}
      </Animated.Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    height: 36,
    justifyContent: 'center',
    overflow: 'hidden',
    paddingHorizontal: 0,
  },
  text: {
    fontSize: 18,
    fontFamily: 'Poppins-Regular',
    whiteSpace: 'nowrap',
  },
});
