import React from 'react';
import {View, StyleSheet} from 'react-native';
import {ScrollTextTicker} from '../shared/ScrollTextTicker';

/**
 * Portrait footer with scrolling ticker - mirrors PortraitFooterView.swift
 */
export function PortraitFooter({
  fontColor = '#FFFFFF',
  bgColor = 'rgba(0,0,0,0.7)',
}: {
  fontColor?: string;
  bgColor?: string;
}) {
  return (
    <View style={[styles.container, {backgroundColor: bgColor}]}>
      <ScrollTextTicker fontColor={fontColor} backgroundColor={bgColor} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    width: '100%',
  },
});
