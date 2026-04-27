import {useEffect, useRef, useCallback} from 'react';
import {useAppStore} from '../store/appStore';
import {useCarouselStore} from '../store/carouselStore';
import {useWeatherStore} from '../store/weatherStore';
import {useEventsStore} from '../store/eventsStore';
import {useStatusIndicatorStore} from '../store/statusIndicatorStore';
import {useSaraAlertStore} from '../store/saraAlertStore';
import {useRadioStore} from '../store/radioStore';
import {useClockStore} from '../store/clockStore';
import {useSiteLogoStore} from '../store/siteLogoStore';
import {useScrollMessageStore} from '../store/scrollMessageStore';
import {shouldFetchData} from '../constants/uiTypes';
import {WS_EVENTS} from '../constants/wsEvents';
import {WebSocketService} from '../services/websocket/WebSocketService';
import {AudioService} from '../services/audio/AudioService';
import {ImageCacheService} from '../services/storage/ImageCacheService';
import {fetchCustomHomePage} from '../services/api/CustomHomePageApi';
import {fetchCarousel} from '../services/api/CarouselApi';
import {fetchWeather} from '../services/api/WeatherApi';
import {fetchEvents} from '../services/api/EventsApi';
import {fetchStatusIndicators} from '../services/api/StatusIndicatorApi';
import {fetchRadio} from '../services/api/RadioApi';
import {fetchSaraAlert} from '../services/api/SaraAlertApi';
import {fetchSiteLogo} from '../services/api/SiteLogoApi';
import {fetchScrollMessage} from '../services/api/ScrollMessageApi';
import {fetchClock} from '../services/api/ClockApi';
import {pushLogsToServer} from '../services/api/LogPushApi';
import {cancelAllRequests} from '../services/api/ApiClient';
import {StorageService} from '../services/storage/StorageService';

/**
 * Central data orchestration hook.
 * Mirrors MainScreenViewController's role as the coordinator between
 * WebSocket triggers, API calls, and store updates.
 *
 * Mounted once in HomeScreen.
 */
export function useDataOrchestrator() {
  const {
    domainAddress: domain,
    roomNumber,
    userId,
    uiType,
    tvRadioFlag,
    isRegistered,
    setUiConfig,
    setWsConnected,
    resetRegistration,
  } = useAppStore();

  const setCarouselSlides = useCarouselStore(s => s.setSlides);
  const clearCarousel = useCarouselStore(s => s.clearSlides);
  const setWeather = useWeatherStore(s => s.setWeatherData);
  const clearWeather = useWeatherStore(s => s.clearWeather);
  const setEvents = useEventsStore(s => s.setEvents);
  const clearEvents = useEventsStore(s => s.clearEvents);
  const setStatusIndicators = useStatusIndicatorStore(s => s.setIndicators);
  const clearStatusIndicators = useStatusIndicatorStore(s => s.clearIndicators);
  const setSaraAlert = useSaraAlertStore(s => s.setSaraAlert);
  const clearSaraAlert = useSaraAlertStore(s => s.clearSaraAlert);
  const setRadio = useRadioStore(s => s.setRadioData);
  const clearRadio = useRadioStore(s => s.clearRadio);
  const showClock = useClockStore(s => s.showClock);
  const hideClock = useClockStore(s => s.hideClock);
  const setLogo = useSiteLogoStore(s => s.setLogo);
  const setScrollMessage = useScrollMessageStore(s => s.setMessage);
  const clearScrollMessage = useScrollMessageStore(s => s.clearMessage);

  const uiTypeRef = useRef(uiType);
  const radioFlagRef = useRef(tvRadioFlag);
  uiTypeRef.current = uiType;
  radioFlagRef.current = tvRadioFlag;

  // --- Individual fetch functions ---

  const loadCarousel = useCallback(async () => {
    try {
      const result = await fetchCarousel(domain, roomNumber, userId);
      if (result) {
        setCarouselSlides(
          result.normalSlides,
          result.adSlides,
          result.globalSlotTime
        );
      } else {
        clearCarousel();
      }
    } catch (e) {
      console.warn('[Orchestrator] Carousel fetch error:', e);
      clearCarousel();
    }
  }, [domain, roomNumber, userId, setCarouselSlides, clearCarousel]);

  const loadWeather = useCallback(async () => {
    try {
      const data = await fetchWeather(domain, roomNumber, userId);
      if (data) {
        setWeather(data);
      } else {
        clearWeather();
      }
    } catch (e) {
      console.warn('[Orchestrator] Weather fetch error:', e);
    }
  }, [domain, roomNumber, userId, setWeather, clearWeather]);

  const loadEvents = useCallback(async () => {
    if (!shouldFetchData('events', uiTypeRef.current)) {
      return;
    }
    try {
      const events = await fetchEvents(domain, roomNumber, userId);
      setEvents(events);
    } catch (e) {
      console.warn('[Orchestrator] Events fetch error:', e);
      clearEvents();
    }
  }, [domain, roomNumber, userId, setEvents, clearEvents]);

  const loadStatusIndicators = useCallback(async () => {
    if (!shouldFetchData('statusIndicators', uiTypeRef.current)) {
      return;
    }
    try {
      const indicators = await fetchStatusIndicators(
        domain,
        roomNumber,
        userId
      );
      setStatusIndicators(indicators);
    } catch (e) {
      console.warn('[Orchestrator] Status indicator fetch error:', e);
      clearStatusIndicators();
    }
  }, [
    domain,
    roomNumber,
    userId,
    setStatusIndicators,
    clearStatusIndicators,
  ]);

  const loadRadio = useCallback(async () => {
    if (
      !shouldFetchData('radio', uiTypeRef.current, radioFlagRef.current)
    ) {
      return;
    }
    try {
      const radioData = await fetchRadio(domain, roomNumber, userId);
      if (radioData) {
        setRadio(radioData.radioUrl, radioData.playingStatus, radioData.radioName);
        if (radioData.playingStatus === 1) {
          await AudioService.playRadio(radioData.radioUrl, radioData.radioName);
        } else {
          await AudioService.stopRadio();
        }
      } else {
        clearRadio();
        await AudioService.stopRadio();
      }
    } catch (e) {
      console.warn('[Orchestrator] Radio fetch error:', e);
    }
  }, [domain, roomNumber, userId, setRadio, clearRadio]);

  const loadSaraAlert = useCallback(async () => {
    try {
      const saraData = await fetchSaraAlert(domain, roomNumber, userId);
      if (saraData) {
        setSaraAlert(saraData);
        if (saraData.hasAudio) {
          await AudioService.playSara(saraData.audioLocalPath);
        }
      } else {
        clearSaraAlert();
        if (AudioService.getCurrentPriority() === 'sara') {
          await AudioService.stopAll();
          await AudioService.resumeRadio();
        }
      }
    } catch (e) {
      console.warn('[Orchestrator] SARA fetch error:', e);
    }
  }, [domain, roomNumber, userId, setSaraAlert, clearSaraAlert]);

  const loadSiteLogo = useCallback(async () => {
    try {
      const logoPath = await fetchSiteLogo(domain, roomNumber, userId);
      if (logoPath) {
        setLogo(logoPath);
      }
    } catch (e) {
      console.warn('[Orchestrator] Site logo fetch error:', e);
    }
  }, [domain, roomNumber, userId, setLogo]);

  const loadScrollMessage = useCallback(async () => {
    try {
      const message = await fetchScrollMessage(domain, roomNumber, userId);
      if (message) {
        setScrollMessage(message);
      } else {
        clearScrollMessage();
      }
    } catch (e) {
      console.warn('[Orchestrator] Scroll message fetch error:', e);
    }
  }, [domain, roomNumber, userId, setScrollMessage, clearScrollMessage]);

  const loadClock = useCallback(async () => {
    try {
      const clockText = await fetchClock(domain, roomNumber, userId);
      if (clockText) {
        showClock(clockText);
      } else {
        hideClock();
      }
    } catch (e) {
      console.warn('[Orchestrator] Clock fetch error:', e);
    }
  }, [domain, roomNumber, userId, showClock, hideClock]);

  const loadCustomHomePage = useCallback(async () => {
    try {
      const config = await fetchCustomHomePage(domain, roomNumber, userId);
      if (config) {
        setUiConfig(config.catieTvType, config.tvStatus, config.tvRadioFlag);
      }
    } catch (e) {
      console.warn('[Orchestrator] Custom home page fetch error:', e);
    }
  }, [domain, roomNumber, userId, setUiConfig]);

  /**
   * Sync all modules in parallel (mirrors syncDataForAllModules())
   * Called on WS connect and on 'All' trigger.
   */
  const syncAllModules = useCallback(async () => {
    console.log('[Orchestrator] Syncing all modules');
    await Promise.allSettled([
      loadCarousel(),
      loadWeather(),
      loadEvents(),
      loadStatusIndicators(),
      loadRadio(),
      loadSaraAlert(),
      loadSiteLogo(),
      loadScrollMessage(),
      loadClock(),
    ]);
  }, [
    loadCarousel,
    loadWeather,
    loadEvents,
    loadStatusIndicators,
    loadRadio,
    loadSaraAlert,
    loadSiteLogo,
    loadScrollMessage,
    loadClock,
  ]);

  // --- WebSocket message dispatch ---
  useEffect(() => {
    if (!isRegistered) {
      return;
    }

    const unsubMessage = WebSocketService.onMessage(async (text: string) => {
      switch (text) {
        case WS_EVENTS.CAROUSEL:
          await loadCarousel();
          break;
        case WS_EVENTS.WEATHER:
          await loadWeather();
          break;
        case WS_EVENTS.EVENTS:
          if (shouldFetchData('events', uiTypeRef.current)) {
            await loadEvents();
          }
          break;
        case WS_EVENTS.STATUS_INDICATOR:
          if (shouldFetchData('statusIndicators', uiTypeRef.current)) {
            await loadStatusIndicators();
          }
          break;
        case WS_EVENTS.RADIO:
          if (
            shouldFetchData(
              'radio',
              uiTypeRef.current,
              radioFlagRef.current
            )
          ) {
            await loadRadio();
          }
          break;
        case WS_EVENTS.SARA_ALERT:
          await loadSaraAlert();
          break;
        case WS_EVENTS.SITE_LOGO:
          await loadSiteLogo();
          break;
        case WS_EVENTS.SCROLL_MESSAGE:
          await loadScrollMessage();
          break;
        case WS_EVENTS.SHOW_CLOCK:
          await loadClock();
          break;
        case WS_EVENTS.HIDE_CLOCK:
          hideClock();
          break;
        case WS_EVENTS.UI_UPDATE:
          await loadCustomHomePage();
          break;
        case WS_EVENTS.SYNC_ALL:
          await syncAllModules();
          break;
        case WS_EVENTS.PUSH_LOGS:
          await pushLogsToServer(domain, roomNumber, userId);
          break;
        case WS_EVENTS.RECONNECT:
          WebSocketService.disconnect();
          setTimeout(() => {
            WebSocketService.connect(domain, roomNumber);
          }, 500);
          break;
        case WS_EVENTS.DETACH:
          await handleDetach();
          break;
        default:
          break;
      }
    });

    const unsubConnected = WebSocketService.onConnected(async () => {
      setWsConnected(true);
      // Load custom home page first, then sync all
      await loadCustomHomePage();
      await syncAllModules();
    });

    const unsubDisconnected = WebSocketService.onDisconnected(() => {
      setWsConnected(false);
    });

    return () => {
      unsubMessage();
      unsubConnected();
      unsubDisconnected();
    };
  }, [
    isRegistered,
    domain,
    roomNumber,
    userId,
    loadCarousel,
    loadWeather,
    loadEvents,
    loadStatusIndicators,
    loadRadio,
    loadSaraAlert,
    loadSiteLogo,
    loadScrollMessage,
    loadClock,
    loadCustomHomePage,
    syncAllModules,
    hideClock,
    setWsConnected,
  ]);

  /**
   * Handle 'detach' message from server.
   * Mirrors the detach handling in SocketConnection.swift
   */
  const handleDetach = useCallback(async () => {
    cancelAllRequests('detach');
    await AudioService.stopAll();
    await ImageCacheService.deleteAll();
    StorageService.clearAll();
    WebSocketService.disconnect();
    resetRegistration();
  }, [resetRegistration]);

  // --- Connect WebSocket when registered ---
  useEffect(() => {
    if (isRegistered && domain && roomNumber) {
      ImageCacheService.init();
      WebSocketService.connect(domain, roomNumber);
    }

    return () => {
      if (!isRegistered) {
        WebSocketService.disconnect();
      }
    };
  }, [isRegistered, domain, roomNumber]);

  return {
    loadCarousel,
    loadWeather,
    loadEvents,
    loadStatusIndicators,
    loadRadio,
    loadSaraAlert,
    loadSiteLogo,
    loadScrollMessage,
    loadClock,
    syncAllModules,
  };
}
