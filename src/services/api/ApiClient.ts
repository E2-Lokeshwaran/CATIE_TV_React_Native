import axios, {
  AxiosInstance,
  CancelTokenSource,
  InternalAxiosRequestConfig,
} from 'axios';
import {useAppStore} from '../../store/appStore';

let apiClient: AxiosInstance | null = null;
let cancelSources: Map<string, CancelTokenSource> = new Map();

/**
 * Creates or returns the axios instance.
 * Mirrors URLSession with API() delegate for SSL bypass.
 */
export function getApiClient(): AxiosInstance {
  if (!apiClient) {
    apiClient = axios.create({
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    apiClient.interceptors.request.use(
      (config: InternalAxiosRequestConfig) => {
        console.log(`[API] ${config.method?.toUpperCase()} ${config.url}`);
        return config;
      },
      error => Promise.reject(error)
    );

    apiClient.interceptors.response.use(
      response => {
        console.log(
          `[API] Response ${response.status} for ${response.config.url}`
        );
        return response;
      },
      error => {
        console.warn(`[API] Error:`, error.message);
        return Promise.reject(error);
      }
    );
  }
  return apiClient;
}

/**
 * Makes a GET request with deduplication (mirrors OngoingAPICallDict pattern).
 * Cancels previous request for the same key if still in-flight.
 */
export async function fetchWithDedup<T>(
  key: string,
  url: string,
  params?: Record<string, string>
): Promise<T> {
  // Cancel any ongoing request for this key
  if (cancelSources.has(key)) {
    cancelSources.get(key)?.cancel(`Cancelled by new ${key} request`);
  }

  const cancelSource = axios.CancelToken.source();
  cancelSources.set(key, cancelSource);

  try {
    const client = getApiClient();
    const response = await client.get<T>(url, {
      params,
      cancelToken: cancelSource.token,
    });
    cancelSources.delete(key);
    return response.data;
  } catch (error) {
    cancelSources.delete(key);
    throw error;
  }
}

/**
 * Cancel all pending API requests.
 * Called on detach or app cleanup.
 */
export function cancelAllRequests(reason = 'App cleanup') {
  cancelSources.forEach(source => source.cancel(reason));
  cancelSources.clear();
}

/**
 * Build full URL from domain-relative path.
 */
export function buildUrl(domain: string, path: string): string {
  return `https://${domain}/catie${path}`;
}
