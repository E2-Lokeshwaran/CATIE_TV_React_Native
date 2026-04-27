import {fetchWithDedup} from './ApiClient';
import {buildApiUrls} from '../../constants/api';
import {RadioData, RadioApiResponse} from '../../types/radio.types';

/**
 * Fetches radio configuration from server.
 * Mirrors RadioModel.getRadioMetaData()
 */
export async function fetchRadio(
  domain: string,
  roomNumber: string,
  userId: string
): Promise<RadioData | null> {
  const urls = buildApiUrls(domain, roomNumber, userId);

  const response = await fetchWithDedup<RadioApiResponse>(
    'Radio',
    urls.radio
  );

  const firstRadio = response.radioList?.[0];
  if (!firstRadio) {
    return null;
  }

  return {
    radioUrl: firstRadio.radioUrl ?? '',
    playingStatus: firstRadio.playingStatus ?? 0,
    radioName: firstRadio.radioName ?? '',
  };
}
