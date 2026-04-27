import {create} from 'zustand';

interface ScrollMessageState {
  message: string;
  isLoaded: boolean;
}

interface ScrollMessageActions {
  setMessage: (message: string) => void;
  clearMessage: () => void;
}

export const useScrollMessageStore = create<
  ScrollMessageState & ScrollMessageActions
>(set => ({
  message: '',
  isLoaded: false,

  setMessage: message => set({message, isLoaded: true}),

  clearMessage: () => set({message: '', isLoaded: false}),
}));
