import {fetchWithDedup} from './ApiClient';
import {buildApiUrls} from '../../constants/api';
import {EventItem, EventsApiResponse} from '../../types/events.types';

/**
 * Fetches events data from server.
 * Mirrors EventsModel.getEventsData()
 */
export async function fetchEvents(
  domain: string,
  roomNumber: string,
  userId: string
): Promise<EventItem[]> {
  const urls = buildApiUrls(domain, roomNumber, userId);

  const response = await fetchWithDedup<EventsApiResponse>(
    'Events',
    urls.events
  );

  const events: EventItem[] = [];

  // Handle both flat eventData and nested eventList formats
  if (response.eventData?.length) {
    for (const item of response.eventData) {
      events.push({
        eventId: item.eventId ?? '',
        title: item.title ?? '',
        location: item.location ?? '',
        startTime: item.startTime ?? '',
        endTime: item.endTime ?? '',
        date: item.eventDate ?? '',
        isOngoing: item.isOngoing ?? false,
        calendarColor: item.calendarColor,
      });
    }
  } else if (response.eventList?.length) {
    for (const calList of response.eventList) {
      const color = calList.calendarColor;
      for (const item of calList.calendarList ?? []) {
        events.push({
          eventId: item.eventId ?? '',
          title: item.title ?? '',
          location: item.location ?? '',
          startTime: item.startTime ?? '',
          endTime: item.endTime ?? '',
          date: item.eventDate ?? '',
          isOngoing: item.isOngoing ?? false,
          calendarColor: color ?? item.calendarColor,
        });
      }
    }
  }

  return events;
}
