import {create} from 'zustand';
import {StatusIndicatorItem} from '../types/status.types';

const ITEMS_PER_PAGE = 4;

interface StatusIndicatorState {
  indicators: StatusIndicatorItem[];
  currentPage: number;
  totalPages: number;
  isLoaded: boolean;
}

interface StatusIndicatorActions {
  setIndicators: (indicators: StatusIndicatorItem[]) => void;
  nextPage: () => void;
  clearIndicators: () => void;
}

export const useStatusIndicatorStore = create<
  StatusIndicatorState & StatusIndicatorActions
>(set => ({
  indicators: [],
  currentPage: 0,
  totalPages: 0,
  isLoaded: false,

  setIndicators: indicators =>
    set({
      indicators,
      currentPage: 0,
      totalPages: Math.ceil(indicators.length / ITEMS_PER_PAGE),
      isLoaded: true,
    }),

  nextPage: () =>
    set(state => ({
      currentPage:
        state.totalPages > 0
          ? (state.currentPage + 1) % state.totalPages
          : 0,
    })),

  clearIndicators: () =>
    set({
      indicators: [],
      currentPage: 0,
      totalPages: 0,
      isLoaded: false,
    }),
}));

export const STATUS_ITEMS_PER_PAGE = ITEMS_PER_PAGE;
