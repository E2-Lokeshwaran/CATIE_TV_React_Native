import React from 'react';
import {
  View,
  Text,
  StyleSheet,
} from 'react-native';
import {useEventsStore} from '../../store/eventsStore';
import {AutoScrollingView} from '../shared/AutoScrollingView';

interface EventsListProps {
  fontColor?: string;
  accentColor?: string;
}

/**
 * Events list component for landscape UI types 1 and 3.
 * Mirrors SingleCalendarEventCell + MultipleCalendarEventCell.
 *
 * Max 45 characters for title and description per AGENTS.md.
 */
export function EventsList({
  fontColor = '#FFFFFF',
  accentColor = '#3773b3',
}: EventsListProps) {
  const {events, hasEvents} = useEventsStore();

  if (!hasEvents) {
    return null;
  }

  return (
    <AutoScrollingView
      scrollDuration={15000}
      scrollDelay={500}
      continuousScrolling
      style={styles.container}>
      {events.map((event, index) => (
        <View
          key={event.eventId || index}
          style={[
            styles.eventCard,
            {
              borderLeftColor: event.calendarColor ?? accentColor,
              backgroundColor: event.isOngoing
                ? 'rgba(55, 115, 179, 0.2)'
                : 'rgba(255,255,255,0.05)',
            },
          ]}>
          <View style={styles.timeColumn}>
            <Text style={[styles.startTime, {color: fontColor}]}>
              {event.startTime}
            </Text>
            {event.endTime ? (
              <Text style={[styles.endTime, {color: `${fontColor}99`}]}>
                {event.endTime}
              </Text>
            ) : null}
          </View>
          <View style={styles.detailsColumn}>
            <Text
              style={[styles.title, {color: fontColor}]}
              numberOfLines={1}>
              {event.title}
            </Text>
            {event.location ? (
              <Text
                style={[styles.location, {color: `${fontColor}BB`}]}
                numberOfLines={1}>
                {event.location}
              </Text>
            ) : null}
          </View>
          {event.isOngoing && (
            <View style={[styles.ongoingBadge, {backgroundColor: accentColor}]}>
              <Text style={styles.ongoingText}>NOW</Text>
            </View>
          )}
        </View>
      ))}
    </AutoScrollingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  eventCard: {
    flexDirection: 'row',
    alignItems: 'center',
    borderLeftWidth: 4,
    borderRadius: 4,
    padding: 8,
    marginBottom: 6,
    gap: 8,
  },
  timeColumn: {
    width: 56,
    alignItems: 'center',
  },
  startTime: {
    fontSize: 14,
    fontWeight: 'bold',
    fontFamily: 'Poppins-Medium',
  },
  endTime: {
    fontSize: 12,
    fontFamily: 'Poppins-Regular',
  },
  detailsColumn: {
    flex: 1,
  },
  title: {
    fontSize: 15,
    fontWeight: '600',
    fontFamily: 'Poppins-Medium',
  },
  location: {
    fontSize: 13,
    fontFamily: 'Poppins-Regular',
    marginTop: 2,
  },
  ongoingBadge: {
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 4,
  },
  ongoingText: {
    color: '#FFFFFF',
    fontSize: 11,
    fontWeight: 'bold',
  },
});
