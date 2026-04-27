import {create} from 'zustand';

interface RadioState {
  radioUrl: string;
  playingStatus: number; // 0=stop, 1=play
  isPlaying: boolean;
  radioName: string;
  isLoaded: boolean;
}

interface RadioActions {
  setRadioData: (url: string, playingStatus: number, name?: string) => void;
  setIsPlaying: (playing: boolean) => void;
  clearRadio: () => void;
}

export const useRadioStore = create<RadioState & RadioActions>(set => ({
  radioUrl: '',
  playingStatus: 0,
  isPlaying: false,
  radioName: '',
  isLoaded: false,

  setRadioData: (url, playingStatus, name = '') =>
    set({
      radioUrl: url,
      playingStatus,
      radioName: name,
      isPlaying: playingStatus === 1,
      isLoaded: true,
    }),

  setIsPlaying: playing => set({isPlaying: playing}),

  clearRadio: () =>
    set({
      radioUrl: '',
      playingStatus: 0,
      isPlaying: false,
      isLoaded: false,
    }),
}));
