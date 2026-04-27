import {fetchWithDedup} from './ApiClient';
import {buildApiUrls} from '../../constants/api';

interface ClockApiResponse {
  status?: string;
  clockText?: string;
  message?: string;
}

/**
 * Fetches clock display settings from server.
 * Mirrors ClockModel.getClockData()
 * Returns null if empty (means hide clock)
 */
export async function fetchClock(
  domain: string,
  roomNumber: string,
  userId: string
): Promise<string | null> {
  const urls = buildApiUrls(domain, roomNumber, userId);

  const response = await fetchWithDedup<ClockApiResponse>(
    'Clock',
    urls.clock
  );

  return response.clockText ?? response.message ?? null;
}
