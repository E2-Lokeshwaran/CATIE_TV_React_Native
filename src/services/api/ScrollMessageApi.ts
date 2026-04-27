import {fetchWithDedup} from './ApiClient';
import {buildApiUrls} from '../../constants/api';

interface ScrollMessageApiResponse {
  status?: string;
  messageList?: ScrollMessageItem[];
  message?: string;
}

interface ScrollMessageItem {
  message?: string;
  messageText?: string;
}

/**
 * Fetches scrolling message data from server.
 * Mirrors ScrollMessageModel.getScrollMessageData()
 */
export async function fetchScrollMessage(
  domain: string,
  roomNumber: string,
  userId: string
): Promise<string | null> {
  const urls = buildApiUrls(domain, roomNumber, userId);

  const response = await fetchWithDedup<ScrollMessageApiResponse>(
    'ScrollMessage',
    urls.scrollMessage
  );

  // Combine all messages into one string
  if (response.messageList?.length) {
    const combined = response.messageList
      .map(item => item.messageText ?? item.message ?? '')
      .filter(Boolean)
      .join('   •   ');
    return combined || null;
  }

  if (response.message) {
    return response.message;
  }

  return null;
}
