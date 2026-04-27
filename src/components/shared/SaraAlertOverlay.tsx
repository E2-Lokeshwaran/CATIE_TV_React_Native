import React, {useEffect, useRef} from 'react';
import {
  View,
  Text,
  StyleSheet,
  Animated,
  ScrollView,
} from 'react-native';
import {useSaraAlertStore} from '../../store/saraAlertStore';

/**
 * SARA Alert full-screen overlay with flashing border.
 * Mirrors PortraitSaraAlertView.swift + landscape SARA alert logic.
 *
 * Features:
 * - Dynamic border color flashing when flash=1
 * - Rich text body with inline styling
 * - Header + body + footer sections
 */
export function SaraAlertOverlay() {
  const {
    isPresent,
    flash,
    flashColor,
    borderColor,
    borderWidth,
    headerText,
    headerFontSize,
    headerFontColor,
    headerBgColor,
    footerText,
    footerFontSize,
    footerFontColor,
    footerBgColor,
    bodyComponents,
  } = useSaraAlertStore();

  const flashAnim = useRef(new Animated.Value(1)).current;
  const flashAnimRef = useRef<Animated.CompositeAnimation | null>(null);

  useEffect(() => {
    if (isPresent && flash === 1) {
      flashAnimRef.current = Animated.loop(
        Animated.sequence([
          Animated.timing(flashAnim, {
            toValue: 0,
            duration: 500,
            useNativeDriver: true,
          }),
          Animated.timing(flashAnim, {
            toValue: 1,
            duration: 500,
            useNativeDriver: true,
          }),
        ])
      );
      flashAnimRef.current.start();
    } else {
      flashAnimRef.current?.stop();
      flashAnim.setValue(1);
    }

    return () => {
      flashAnimRef.current?.stop();
    };
  }, [isPresent, flash, flashColor, flashAnim]);

  if (!isPresent) {
    return null;
  }

  const currentBorderColor = flash === 1 ? flashColor : borderColor;

  return (
    <View style={StyleSheet.absoluteFillObject}>
      <Animated.View
        style={[
          styles.container,
          {
            borderColor: currentBorderColor,
            borderWidth,
            opacity: flash === 1 ? flashAnim : 1,
          },
        ]}>
        {/* Header */}
        {headerText ? (
          <View style={[styles.header, {backgroundColor: headerBgColor}]}>
            <Text
              style={[
                styles.headerText,
                {fontSize: headerFontSize, color: headerFontColor},
              ]}>
              {headerText}
            </Text>
          </View>
        ) : null}

        {/* Body */}
        <ScrollView style={styles.body} contentContainerStyle={styles.bodyContent}>
          {bodyComponents.map((component, lineIdx) => (
            <View key={`line_${lineIdx}`} style={styles.bodyLine}>
              {component.items.map((item, itemIdx) => (
                <Text
                  key={`item_${itemIdx}`}
                  style={[
                    styles.bodyText,
                    {
                      fontSize: item.fontSize,
                      color: item.fontColor,
                      fontWeight: item.fontWeight,
                      fontStyle: item.fontStyle,
                    },
                  ]}>
                  {item.pointer ? `${item.pointer} ` : ''}
                  {item.text}
                </Text>
              ))}
            </View>
          ))}
        </ScrollView>

        {/* Footer */}
        {footerText ? (
          <View style={[styles.footer, {backgroundColor: footerBgColor}]}>
            <Text
              style={[
                styles.footerText,
                {fontSize: footerFontSize, color: footerFontColor},
              ]}>
              {footerText}
            </Text>
          </View>
        ) : null}
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.92)',
    margin: 20,
    borderRadius: 8,
    overflow: 'hidden',
  },
  header: {
    padding: 16,
    alignItems: 'center',
  },
  headerText: {
    fontWeight: 'bold',
    textAlign: 'center',
  },
  body: {
    flex: 1,
    padding: 16,
  },
  bodyContent: {
    paddingBottom: 16,
  },
  bodyLine: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    marginBottom: 4,
  },
  bodyText: {
    lineHeight: 24,
  },
  footer: {
    padding: 12,
    alignItems: 'center',
  },
  footerText: {
    textAlign: 'center',
  },
});
