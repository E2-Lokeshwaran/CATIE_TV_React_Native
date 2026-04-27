import {fetchWithDedup} from './ApiClient';
import {buildApiUrls} from '../../constants/api';
import {
  StatusIndicatorItem,
  StatusIndicatorApiResponse,
} from '../../types/status.types';

/**
 * Fetches status indicator data from server.
 * Mirrors StatusIndicatorModel.getStatusIndicatorData()
 */
export async function fetchStatusIndicators(
  domain: string,
  roomNumber: string,
  userId: string
): Promise<StatusIndicatorItem[]> {
  const urls = buildApiUrls(domain, roomNumber, userId);

  const response = await fetchWithDedup<StatusIndicatorApiResponse>(
    'StatusIndicator',
    urls.statusIndicator
  );

  return (response.statusIndicatorList ?? []).map((item, index) => ({
    statusId: item.statusId ?? `status_${index}`,
    title: (item.title ?? '').substring(0, 45), // 45 char limit from AGENTS.md
    description: (item.description ?? '').substring(0, 45),
    statusFlag: item.statusFlag ?? 0,
    iconType: item.iconType,
    iconColor: item.iconColor,
  }));
}
