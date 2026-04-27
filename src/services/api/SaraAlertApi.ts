import {fetchWithDedup} from './ApiClient';
import {buildApiUrls} from '../../constants/api';
import {ImageCacheService} from '../storage/ImageCacheService';
import {
  SaraAlertData,
  SaraAlertApiResponse,
  BodyTextComponent,
} from '../../types/sara.types';

/**
 * Fetches SARA alert data from server, downloads audio if present.
 * Mirrors SaraAlertModel.getSaraAlertData()
 */
export async function fetchSaraAlert(
  domain: string,
  roomNumber: string,
  userId: string
): Promise<SaraAlertData | null> {
  const urls = buildApiUrls(domain, roomNumber, userId);

  const response = await fetchWithDedup<SaraAlertApiResponse>(
    'SaraAlert',
    urls.saraAlert
  );

  const saraItem = response.saraAlertList?.[0];
  if (!saraItem) {
    return null; // Empty response = clear SARA alert
  }

  // Download audio if present
  let audioLocalPath = '';
  let hasAudio = false;
  if (saraItem.audioPath) {
    const audioUrl = `https://${domain}${saraItem.audioPath}`;
    const audioFileName = saraItem.audioPath.split('/').pop() ?? 'sara_audio';
    try {
      const cached = await ImageCacheService.audioExists(audioFileName);
      if (cached) {
        audioLocalPath = ImageCacheService.getAudioUri(audioFileName);
      } else {
        audioLocalPath = await ImageCacheService.downloadAudio(
          audioFileName,
          audioUrl
        );
      }
      hasAudio = true;
    } catch (e) {
      console.warn('[SaraAlertApi] Failed to download audio:', e);
    }
  }

  // Parse rich body text components
  const bodyComponents: BodyTextComponent[] = [];
  for (const bodyText of saraItem.body?.bodyTextList ?? []) {
    const items = (bodyText.bodyIndividualList ?? []).map(individual => ({
      text: individual.text ?? '',
      fontSize: individual.fontSize ?? 16,
      fontColor: individual.fontColor ?? '#FFFFFF',
      fontWeight:
        individual.fontWeight === 'bold'
          ? ('bold' as const)
          : ('normal' as const),
      fontStyle:
        individual.fontStyle === 'italic'
          ? ('italic' as const)
          : ('normal' as const),
      pointer: individual.pointer,
    }));

    bodyComponents.push({
      lineKey: bodyText.lineKey ?? '',
      items,
    });
  }

  return {
    isPresent: true,
    flash: saraItem.flash ?? 0,
    flashColor: saraItem.flashColor ?? '#FF0000',
    borderColor: saraItem.borderColor ?? '#FF0000',
    borderWidth: saraItem.borderWidth ?? 3,
    audioLocalPath,
    hasAudio,
    header: {
      text: saraItem.header?.headerText ?? '',
      fontSize: saraItem.header?.fontSize ?? 20,
      fontColor: saraItem.header?.fontColor ?? '#FFFFFF',
      backgroundColor: saraItem.header?.backgroundColor ?? '#FF0000',
      textAlign: (saraItem.header?.textAlign as 'left' | 'center' | 'right') ?? 'center',
    },
    footer: {
      text: saraItem.footer?.footerText ?? '',
      fontSize: saraItem.footer?.fontSize ?? 16,
      fontColor: saraItem.footer?.fontColor ?? '#FFFFFF',
      backgroundColor: saraItem.footer?.backgroundColor ?? '#FF0000',
      textAlign: (saraItem.footer?.textAlign as 'left' | 'center' | 'right') ?? 'center',
    },
    bodyComponents,
  };
}
