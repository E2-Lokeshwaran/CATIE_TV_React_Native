import React from 'react';
import {View, Text, StyleSheet} from 'react-native';
import {useStatusIndicatorStore, STATUS_ITEMS_PER_PAGE} from '../../store/statusIndicatorStore';

/**
 * Status indicator list with paged cycling.
 * Mirrors StatusIndicatorCollectionViewCell.
 * Shows 4 items per page, cycles every 10s (managed by useTimerManager).
 *
 * Max 45 chars for title and description per AGENTS.md.
 */
export function StatusIndicatorList({
  fontColor = '#FFFFFF',
}: {
  fontColor?: string;
}) {
  const {indicators, currentPage} = useStatusIndicatorStore();

  if (indicators.length === 0) {
    return null;
  }

  const startIndex = currentPage * STATUS_ITEMS_PER_PAGE;
  const pageItems = indicators.slice(
    startIndex,
    startIndex + STATUS_ITEMS_PER_PAGE
  );

  return (
    <View style={styles.container}>
      {pageItems.map((item, index) => (
        <View
          key={item.statusId || index}
          style={[
            styles.indicatorItem,
            {
              backgroundColor:
                item.statusFlag === 1
                  ? 'rgba(0, 200, 100, 0.15)'
                  : 'rgba(255, 100, 100, 0.15)',
            },
          ]}>
          {/* Status dot */}
          <View
            style={[
              styles.statusDot,
              {
                backgroundColor:
                  item.statusFlag === 1 ? '#00C864' : '#FF6464',
              },
            ]}
          />
          <View style={styles.textContainer}>
            <Text
              style={[styles.title, {color: fontColor}]}
              numberOfLines={1}>
              {item.title}
            </Text>
            <Text
              style={[styles.description, {color: `${fontColor}BB`}]}
              numberOfLines={1}>
              {item.description}
            </Text>
          </View>
        </View>
      ))}

      {/* Page dots */}
      {indicators.length > STATUS_ITEMS_PER_PAGE && (
        <View style={styles.pageDots}>
          {Array.from({
            length: Math.ceil(indicators.length / STATUS_ITEMS_PER_PAGE),
          }).map((_, i) => (
            <View
              key={i}
              style={[
                styles.dot,
                {
                  backgroundColor:
                    i === currentPage
                      ? fontColor
                      : `${fontColor}44`,
                },
              ]}
            />
          ))}
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    gap: 8,
  },
  indicatorItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 10,
    borderRadius: 6,
    gap: 10,
  },
  statusDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    flexShrink: 0,
  },
  textContainer: {
    flex: 1,
  },
  title: {
    fontSize: 15,
    fontWeight: '600',
    fontFamily: 'Poppins-Medium',
  },
  description: {
    fontSize: 13,
    fontFamily: 'Poppins-Regular',
    marginTop: 2,
  },
  pageDots: {
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 6,
    paddingTop: 4,
  },
  dot: {
    width: 6,
    height: 6,
    borderRadius: 3,
  },
});
