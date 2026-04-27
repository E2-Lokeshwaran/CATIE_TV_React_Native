import {fetchWithDedup} from './ApiClient';
import {buildApiUrls} from '../../constants/api';
import {ImageCacheService} from '../storage/ImageCacheService';
import {
  CarouselApiResponse,
  CarouselSlide,
} from '../../types/carousel.types';

/**
 * Fetches carousel data from server and downloads new images.
 * Mirrors CarousalModel.getCarousalData() + processCarousalResponseData()
 *
 * - Separates normal (type 0,1) from advertisement (type 2) slides
 * - Reuses cached images if unchanged (deduplication)
 * - Downloads only new/changed images
 */
export async function fetchCarousel(
  domain: string,
  roomNumber: string,
  userId: string
): Promise<{
  normalSlides: CarouselSlide[];
  adSlides: CarouselSlide[];
  globalSlotTime: number;
} | null> {
  const urls = buildApiUrls(domain, roomNumber, userId);

  // 4s delay matching the Swift code to avoid half-broken images
  await new Promise(resolve => setTimeout(resolve, 4000));

  const response = await fetchWithDedup<CarouselApiResponse>(
    'Carousal',
    urls.carousel
  );

  if (response.status !== 'success' || !response.data?.length) {
    return null;
  }

  const globalSlotTime = response.slotTime || 5;
  const normalSlides: CarouselSlide[] = [];
  const adSlides: CarouselSlide[] = [];

  await Promise.all(
    response.data.map(async item => {
      const scheduleImagePath = item.scheduleImagePath;
      if (!scheduleImagePath) {
        return;
      }

      // Extract image name from path (mirrors Swift logic)
      const imageFilePath = scheduleImagePath.split('&')[0];
      const imageName = imageFilePath.split('=').pop();
      if (!imageName) {
        return;
      }

      // Build audio URL
      const audioPath =
        item.audioPath && item.audioPath.length > 0
          ? `https://${domain}${item.audioPath}`
          : '';

      // Get slide type
      const carouselType = item.slideDetails?.carouselType ?? 0;
      const slotTime =
        carouselType === 1
          ? item.slideDetails?.timeout ?? globalSlotTime
          : globalSlotTime;

      // Check if image already cached (deduplication - mirrors existingCarousalDict)
      let imageLocalPath: string;
      const cached = await ImageCacheService.imageExists(imageName);

      if (cached) {
        imageLocalPath = ImageCacheService.getImageUri(imageName);
      } else {
        // Download the new image
        const imageUrl = `https://${domain}/catie${scheduleImagePath}`;
        try {
          imageLocalPath = await ImageCacheService.downloadImage(
            imageName,
            imageUrl
          );
        } catch (e) {
          console.warn(`[CarouselApi] Failed to download image ${imageName}:`, e);
          imageLocalPath = '';
        }
      }

      const slide: CarouselSlide = {
        imageName,
        imageLocalPath,
        audioPath,
        audioFlag: audioPath.length > 0,
        slotTime,
        carouselType,
      };

      if (carouselType === 2) {
        adSlides.push(slide);
      } else {
        normalSlides.push(slide);
      }
    })
  );

  return {normalSlides, adSlides, globalSlotTime};
}
