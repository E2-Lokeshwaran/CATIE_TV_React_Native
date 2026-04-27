import React from 'react';
import {View, Text, StyleSheet} from 'react-native';
import {useStatusIndicatorStore} from '../../store/statusIndicatorStore';

/**
 * Portrait status indicators - mirrors PortraitStatusIndicatorView.swift
 */
export function PortraitStatusIndicatorView({
  fontColor = '#FFFFFF',
}: {
  fontColor?: string;
}) {
  const {indicators} = useStatusIndicatorStore();

  if (indicators.length === 0) {
    return null;
  }

  return (
    <View style={styles.container}>
      {indicators.slice(0, 4).map((item, i) => (
        <View key={item.statusId || i} style={styles.item}>
          <View
            style={[
              styles.dot,
              {backgroundColor: item.statusFlag === 1 ? '#00C864' : '#FF6464'},
            ]}
          />
          <Text style={[styles.text, {color: fontColor}]} numberOfLines={1}>
            {item.title}
          </Text>
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    padding: 8,
    gap: 6,
  },
  item: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  dot: {
    width: 10,
    height: 10,
    borderRadius: 5,
  },
  text: {
    fontSize: 13,
    fontFamily: 'Poppins-Regular',
    flex: 1,
  },
});
