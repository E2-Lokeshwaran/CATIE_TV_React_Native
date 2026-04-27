import {create} from 'zustand';
import {MMKV} from 'react-native-mmkv';

const storage = new MMKV({id: 'catie-app-store'});

interface AppState {
  // Registration
  isRegistered: boolean;
  domainAddress: string;
  roomNumber: string;
  userId: string;
  // TV state
  tvStatus: number; // 0=unregistered, 1=active
  uiType: number; // 1-6
  tvRadioFlag: number; // 0 or 1
  // Network & connection
  isNetworkDown: boolean;
  isWsConnected: boolean;
  communicationStatus: string;
  // App state
  isLoading: boolean;
  isItFirstLaunch: boolean;
}

interface AppActions {
  setRegistration: (
    domain: string,
    roomNumber: string,
    userId: string
  ) => void;
  setUiConfig: (
    uiType: number,
    tvStatus: number,
    tvRadioFlag: number
  ) => void;
  setNetworkDown: (isDown: boolean) => void;
  setWsConnected: (connected: boolean) => void;
  setCommunicationStatus: (status: string) => void;
  setLoading: (loading: boolean) => void;
  resetRegistration: () => void;
  loadPersistedData: () => void;
}

// Load persisted registration data
const persistedDomain = storage.getString('domainAddress') ?? '';
const persistedRoom = storage.getString('roomNumber') ?? '';
const persistedUserId = storage.getString('userId') ?? '';

export const useAppStore = create<AppState & AppActions>(set => ({
  isRegistered: !!(persistedDomain && persistedRoom && persistedUserId),
  domainAddress: persistedDomain,
  roomNumber: persistedRoom,
  userId: persistedUserId,
  tvStatus: 1,
  uiType: 1,
  tvRadioFlag: 1,
  isNetworkDown: false,
  isWsConnected: false,
  communicationStatus: '1',
  isLoading: false,
  isItFirstLaunch: true,

  setRegistration: (domain, roomNumber, userId) => {
    storage.set('domainAddress', domain);
    storage.set('roomNumber', roomNumber);
    storage.set('userId', userId);
    set({
      domainAddress: domain,
      roomNumber: roomNumber,
      userId: userId,
      isRegistered: true,
    });
  },

  setUiConfig: (uiType, tvStatus, tvRadioFlag) => {
    set({uiType, tvStatus, tvRadioFlag});
  },

  setNetworkDown: isDown => set({isNetworkDown: isDown}),

  setWsConnected: connected =>
    set(state => ({
      isWsConnected: connected,
      isItFirstLaunch: connected ? false : state.isItFirstLaunch,
    })),

  setCommunicationStatus: status => set({communicationStatus: status}),

  setLoading: loading => set({isLoading: loading}),

  resetRegistration: () => {
    storage.delete('domainAddress');
    storage.delete('roomNumber');
    storage.delete('userId');
    set({
      isRegistered: false,
      domainAddress: '',
      roomNumber: '',
      userId: '',
      tvStatus: 0,
      isWsConnected: false,
    });
  },

  loadPersistedData: () => {
    const domain = storage.getString('domainAddress') ?? '';
    const room = storage.getString('roomNumber') ?? '';
    const uid = storage.getString('userId') ?? '';
    set({
      domainAddress: domain,
      roomNumber: room,
      userId: uid,
      isRegistered: !!(domain && room && uid),
    });
  },
}));
