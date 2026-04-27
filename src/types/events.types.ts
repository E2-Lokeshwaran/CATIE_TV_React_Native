export interface EventItem {
  eventId: string;
  title: string;
  location: string;
  startTime: string;
  endTime: string;
  date: string;
  isOngoing: boolean;
  calendarColor?: string;
}

export interface EventsApiResponse {
  status?: string;
  eventData?: EventApiItem[];
  eventList?: EventListApiItem[];
}

export interface EventApiItem {
  eventId?: string;
  title?: string;
  location?: string;
  startTime?: string;
  endTime?: string;
  eventDate?: string;
  isOngoing?: boolean;
  calendarColor?: string;
}

export interface EventListApiItem {
  calendarList?: EventApiItem[];
  calendarName?: string;
  calendarColor?: string;
}
