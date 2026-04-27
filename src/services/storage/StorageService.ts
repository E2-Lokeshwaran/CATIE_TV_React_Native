import {MMKV} from 'react-native-mmkv';

const mmkv = new MMKV({id: 'catie-tv-state'});

/**
 * Replaces StatusCodeDict.shared and OngoingAPICallDict.shared from Swift.
 * Thread-safe key-value storage using MMKV.
 */
export const StorageService = {
  // Status codes for each module (mirrors StatusCodeDict)
  setStatusCode: (key: string, value: number) => {
    mmkv.set(`statusCode_${key}`, value);
  },
  getStatusCode: (key: string): number => {
    return mmkv.getNumber(`statusCode_${key}`) ?? 0;
  },

  // Ongoing API call tracking (mirrors OngoingAPICallDict)
  setOngoingApiCall: (key: string, value: boolean) => {
    mmkv.set(`ongoing_${key}`, value);
  },
  getOngoingApiCall: (key: string): boolean => {
    return mmkv.getBoolean(`ongoing_${key}`) ?? false;
  },

  // Pending API call tracking (mirrors PendingAPICallRequestDict)
  setPendingApiCall: (key: string, value: boolean) => {
    mmkv.set(`pending_${key}`, value);
  },
  getPendingApiCall: (key: string): boolean => {
    return mmkv.getBoolean(`pending_${key}`) ?? false;
  },

  // General persist/load
  set: (key: string, value: string | number | boolean) => {
    if (typeof value === 'string') {
      mmkv.set(key, value);
    } else if (typeof value === 'number') {
      mmkv.set(key, value);
    } else {
      mmkv.set(key, value);
    }
  },
  getString: (key: string): string => mmkv.getString(key) ?? '',
  getNumber: (key: string): number => mmkv.getNumber(key) ?? 0,
  getBoolean: (key: string): boolean => mmkv.getBoolean(key) ?? false,
  delete: (key: string) => mmkv.delete(key),

  // Clears registration data (mirrors ApplicationState.resetUserDefaults())
  clearRegistration: () => {
    mmkv.delete('domainAddress');
    mmkv.delete('roomNumber');
    mmkv.delete('userId');
  },

  // Clear all state
  clearAll: () => {
    mmkv.clearAll();
  },
};
