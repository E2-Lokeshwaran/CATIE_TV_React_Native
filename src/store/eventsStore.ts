import {create} from 'zustand';
import {EventItem} from '../types/events.types';

interface EventsState {
  events: EventItem[];
  hasEvents: boolean;
  isLoaded: boolean;
}

interface EventsActions {
  setEvents: (events: EventItem[]) => void;
  clearEvents: () => void;
}

export const useEventsStore = create<EventsState & EventsActions>(set => ({
  events: [],
  hasEvents: false,
  isLoaded: false,

  setEvents: events =>
    set({
      events,
      hasEvents: events.length > 0,
      isLoaded: true,
    }),

  clearEvents: () =>
    set({
      events: [],
      hasEvents: false,
      isLoaded: false,
    }),
}));
