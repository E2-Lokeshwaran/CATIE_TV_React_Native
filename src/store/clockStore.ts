import {create} from 'zustand';

interface ClockState {
  isClockPresented: boolean;
  clockMessage: string;
}

interface ClockActions {
  showClock: (message: string) => void;
  hideClock: () => void;
}

export const useClockStore = create<ClockState & ClockActions>(set => ({
  isClockPresented: false,
  clockMessage: '',

  showClock: message => set({isClockPresented: true, clockMessage: message}),

  hideClock: () => set({isClockPresented: false, clockMessage: ''}),
}));
