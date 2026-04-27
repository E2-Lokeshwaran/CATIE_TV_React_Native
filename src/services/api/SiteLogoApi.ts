import {fetchWithDedup} from './ApiClient';
import {buildApiUrls} from '../../constants/api';
import {ImageCacheService} from '../storage/ImageCacheService';

interface SiteLogoApiResponse {
  status?: string;
  imagePath?: string;
  imageData?: string;
}

/**
 * Fetches site logo from server and caches locally.
 * Mirrors SiteLogoModel.getSiteLogoData()
 */
export async function fetchSiteLogo(
  domain: string,
  roomNumber: string,
  userId: string
): Promise<string | null> {
  const urls = buildApiUrls(domain, roomNumber, userId);

  const response = await fetchWithDedup<SiteLogoApiResponse>(
    'SiteLogo',
    urls.siteLogo
  );

  if (!response.imagePath) {
    return null;
  }

  const imageName = response.imagePath.split('/').pop() ?? 'site_logo';
  const imageUrl = `https://${domain}/catie${response.imagePath}`;

  try {
    const cached = await ImageCacheService.imageExists(imageName);
    if (cached) {
      return ImageCacheService.getImageUri(imageName);
    }
    return await ImageCacheService.downloadImage(imageName, imageUrl);
  } catch (e) {
    console.warn('[SiteLogoApi] Failed to download site logo:', e);
    return null;
  }
}
