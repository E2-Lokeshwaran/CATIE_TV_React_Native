import {fetchWithDedup} from './ApiClient';
import {buildApiUrls} from '../../constants/api';
import {
  CustomHomePageApiResponse,
  CustomHomePageData,
} from '../../types/customHomePage.types';

/**
 * Fetches custom home page config from server.
 * Mirrors CustomHomePageModel.getCustomHomePageData()
 *
 * Response sets uiType, tvStatus, tvRadioFlag, font settings.
 * This must be called first on WS connect before any other fetch.
 */
export async function fetchCustomHomePage(
  domain: string,
  roomNumber: string,
  userId: string
): Promise<CustomHomePageData | null> {
  const urls = buildApiUrls(domain, roomNumber, userId);

  const response = await fetchWithDedup<CustomHomePageApiResponse>(
    'CustomPage',
    urls.customHomePage
  );

  if (
    response.status === 'success' &&
    response.data &&
    !isDataEmpty(response.data)
  ) {
    return {
      catieTvFontColor: response.data.catieTvFontColor ?? '#3773b3',
      catieTvFontSize: response.data.catieTvFontSize ?? '50',
      catieTvFontType: response.data.catieTvFontType ?? 'System',
      catieTvType: response.data.catieTvType ?? 1,
      tvStatus: response.data.tvStatus ?? 1,
      tvRadioFlag: response.data.tvRadioFlag ?? 1,
    };
  }

  return null;
}

function isDataEmpty(data: NonNullable<CustomHomePageApiResponse['data']>) {
  return (
    data.catieTvFontColor == null &&
    data.catieTvFontSize == null &&
    data.catieTvType == null &&
    data.catieTvFontType == null &&
    data.tvStatus == null &&
    data.tvRadioFlag == null
  );
}
