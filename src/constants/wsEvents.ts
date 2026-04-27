// WebSocket event trigger strings - mirrors SocketConnection.swift message dispatch
export const WS_EVENTS = {
  CAROUSEL: 'carousal',
  WEATHER: 'weather',
  EVENTS: 'event',
  STATUS_INDICATOR: 'statusIndicator',
  RADIO: 'Radio',
  SITE_LOGO: 'icon',
  SCROLL_MESSAGE: 'scrollmsg',
  SARA_ALERT: 'saraAlert',
  DETACH: 'detach',
  SYNC_ALL: 'All',
  PUSH_LOGS: 'PushLogs',
  SHOW_CLOCK: 'showClock',
  HIDE_CLOCK: 'hideClock',
  UI_UPDATE: 'tvUIUpdate',
  RECONNECT: 'Reconnect Websocket',
} as const;

export type WsEventType = (typeof WS_EVENTS)[keyof typeof WS_EVENTS];
