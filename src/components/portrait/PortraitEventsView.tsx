import React from 'react';
import {View, Text, StyleSheet} from 'react-native';
import {useEventsStore} from '../../store/eventsStore';
import {AutoScrollingView} from '../shared/AutoScrollingView';

/**
 * Portrait events list - mirrors PortraitEventsView.swift
 * Uses AutoScrollingView for smooth vertical auto-scroll (same as Swift AutoScrollingScrollView).
 */
export function PortraitEventsView({
  fontColor = '#FFFFFF',
  accentColor = '#3773b3',
}: {
  fontColor?: string;
  accentColor?: string;
}) {
  const {events} = useEventsStore();

  if (events.length === 0) {
    return null;
  }

  return (
    <AutoScrollingView
      scrollDuration={15000}
      scrollDelay={500}
      continuousScrolling
      style={styles.container}>
      {events.map((event, i) => (
        <View
          key={event.eventId || i}
          style={[
            styles.event,
            {borderLeftColor: event.calendarColor ?? accentColor},
          ]}>
          <Text style={[styles.time, {color: fontColor}]}>
            {event.startTime}
            {event.endTime ? ` - ${event.endTime}` : ''}
          </Text>
          <Text style={[styles.title, {color: fontColor}]} numberOfLines={1}>
            {event.title}
          </Text>
          {event.location ? (
            <Text
              style={[styles.location, {color: `${fontColor}AA`}]}
              numberOfLines={1}>
              {event.location}
            </Text>
          ) : null}
        </View>
      ))}
    </AutoScrollingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  event: {
    borderLeftWidth: 3,
    paddingLeft: 10,
    paddingVertical: 6,
    marginBottom: 8,
    backgroundColor: 'rgba(255,255,255,0.06)',
    borderRadius: 4,
  },
  time: {
    fontSize: 12,
    fontFamily: 'Poppins-Regular',
  },
  title: {
    fontSize: 14,
    fontWeight: '600',
    fontFamily: 'Poppins-Medium',
  },
  location: {
    fontSize: 12,
    fontFamily: 'Poppins-Regular',
  },
});
