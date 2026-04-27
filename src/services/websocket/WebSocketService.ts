import {WS_EVENTS} from '../../constants/wsEvents';

type MessageHandler = (text: string) => void;
type ConnectionHandler = () => void;

const RECONNECT_DELAY = 30000; // 30 seconds (matches Swift)
const WATCHDOG_TIMEOUT = 20000; // 20 seconds (matches Swift)
const MIN_RECONNECT_INTERVAL = 5000; // 5 seconds min between attempts
const PING_INTERVAL = 60000; // 60 seconds

/**
 * WebSocket service for real-time server communication.
 * Mirrors webSocketConnection class in SocketConnection.swift.
 *
 * Features:
 * - 30s fixed reconnect backoff
 * - 20s connection watchdog
 * - 5s minimum between attempts
 * - Ping/device-details every 60s
 */
class WebSocketServiceClass {
  private ws: WebSocket | null = null;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private watchdogTimer: ReturnType<typeof setTimeout> | null = null;
  private pingTimer: ReturnType<typeof setTimeout> | null = null;
  private isReconnecting = false;
  private isConnected = false;
  private lastReconnectTime = 0;
  private reconnectAttempts = 0;
  private domain = '';
  private roomNumber = '';

  private onMessageHandlers: Set<MessageHandler> = new Set();
  private onConnectedHandlers: Set<ConnectionHandler> = new Set();
  private onDisconnectedHandlers: Set<ConnectionHandler> = new Set();

  private deviceDetailsGetter: (() => Record<string, string>) | null = null;
  private tvStatusGetter: (() => number) | null = null;

  /**
   * Configure dependency injectors to avoid circular imports.
   */
  configure(
    deviceDetailsGetter: () => Record<string, string>,
    tvStatusGetter: () => number
  ) {
    this.deviceDetailsGetter = deviceDetailsGetter;
    this.tvStatusGetter = tvStatusGetter;
  }

  /**
   * Start WebSocket connection.
   * Mirrors startSocketConnection(withAddress:roomNumber:)
   */
  connect(domain: string, roomNumber: string) {
    this.domain = domain;
    this.roomNumber = roomNumber;

    // Throttle rapid reconnection attempts
    const now = Date.now();
    if (now - this.lastReconnectTime < MIN_RECONNECT_INTERVAL) {
      console.log('[WS] Throttling reconnect attempt');
      return;
    }
    this.lastReconnectTime = now;

    this.cancelWatchdog();
    this.isReconnecting = false;

    // Close existing connection
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }

    const urlString = `wss://${domain}/webnotification/webnotifier/${roomNumber.toLowerCase()}/notification`;
    console.log(`[WS] Connecting to ${urlString}`);

    try {
      this.ws = new WebSocket(urlString);
      this.startWatchdog();
      this.setupHandlers();
    } catch (e) {
      console.warn('[WS] Failed to create WebSocket:', e);
      this.scheduleReconnect('connection exception');
    }
  }

  private setupHandlers() {
    if (!this.ws) {
      return;
    }

    this.ws.onopen = () => {
      console.log('[WS] Connected');
      this.isConnected = true;
      this.isReconnecting = false;
      this.reconnectAttempts = 0;
      this.cancelWatchdog();
      this.cancelReconnect();

      // Send device details on connect
      this.sendDeviceDetails();

      // Start 60s ping timers
      this.startPingTimers();

      this.onConnectedHandlers.forEach(h => h());
    };

    this.ws.onmessage = event => {
      const text = event.data as string;
      console.log(`[WS] Message: ${text}`);
      this.onMessageHandlers.forEach(h => h(text));
    };

    this.ws.onerror = event => {
      console.warn('[WS] Error:', event);
      this.isConnected = false;
      this.cancelWatchdog();
      this.scheduleReconnect('websocket error');
    };

    this.ws.onclose = event => {
      console.log(`[WS] Disconnected: reason=${event.reason} code=${event.code}`);
      this.isConnected = false;
      this.cancelWatchdog();
      this.stopPingTimers();
      this.onDisconnectedHandlers.forEach(h => h());

      const tvStatus = this.tvStatusGetter?.() ?? 1;
      if (tvStatus === 1) {
        this.scheduleReconnect(`disconnected: ${event.reason} (code: ${event.code})`);
      }
    };
  }

  /**
   * Schedule reconnection with fixed 30s delay.
   * Mirrors scheduleReconnection(reason:)
   */
  private scheduleReconnect(reason: string) {
    const tvStatus = this.tvStatusGetter?.() ?? 1;
    if (tvStatus !== 1) {
      console.log('[WS] Skipping reconnect - not registered');
      return;
    }

    if (this.isReconnecting) {
      this.cancelReconnect();
    }

    this.isReconnecting = true;
    this.reconnectAttempts += 1;

    console.log(
      `[WS] Scheduling reconnect in ${RECONNECT_DELAY / 1000}s (reason: ${reason}, attempt: #${this.reconnectAttempts})`
    );

    this.reconnectTimer = setTimeout(() => {
      if (!this.isReconnecting) {
        return;
      }
      this.reconnectTimer = null;
      if (this.domain && this.roomNumber) {
        this.connect(this.domain, this.roomNumber);
      }
    }, RECONNECT_DELAY);
  }

  /**
   * Start 20s watchdog to detect silent failures.
   * Mirrors startConnectionWatchdog()
   */
  private startWatchdog() {
    this.cancelWatchdog();
    this.watchdogTimer = setTimeout(() => {
      if (!this.isConnected) {
        console.log('[WS] Watchdog triggered - forcing reconnect');
        this.ws?.close();
        this.scheduleReconnect('watchdog timeout');
      }
    }, WATCHDOG_TIMEOUT);
  }

  private cancelWatchdog() {
    if (this.watchdogTimer) {
      clearTimeout(this.watchdogTimer);
      this.watchdogTimer = null;
    }
  }

  cancelReconnect() {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
    this.cancelWatchdog();
    this.isReconnecting = false;
  }

  /**
   * Start 60s ping and device detail timers.
   */
  private startPingTimers() {
    this.stopPingTimers();
    this.pingTimer = setInterval(() => {
      this.sendPing();
      this.sendDeviceDetails();
    }, PING_INTERVAL);
  }

  private stopPingTimers() {
    if (this.pingTimer) {
      clearInterval(this.pingTimer);
      this.pingTimer = null;
    }
  }

  /**
   * Send device details JSON to server.
   * Mirrors sendDeviceDetailsToServer()
   */
  sendDeviceDetails() {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      return;
    }
    const details = this.deviceDetailsGetter?.() ?? {};
    const json = JSON.stringify({
      ...details,
      module: 'deviceStatus',
      status: 'connected',
    });
    const message = `CATIE-SERVER:${json}`;
    this.ws.send(message);
    console.log('[WS] Sent device details');
  }

  /**
   * Send ping to server.
   * Mirrors SendPingToServer()
   */
  private sendPing() {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      return;
    }
    this.ws.send(`${this.roomNumber.toLowerCase()}:ping`);
  }

  /**
   * Close WebSocket connection.
   * Mirrors closeSocketConnection()
   */
  disconnect() {
    this.cancelReconnect();
    this.stopPingTimers();
    this.ws?.close();
    this.ws = null;
    this.isConnected = false;
  }

  // Event subscriptions
  onMessage(handler: MessageHandler): () => void {
    this.onMessageHandlers.add(handler);
    return () => this.onMessageHandlers.delete(handler);
  }

  onConnected(handler: ConnectionHandler): () => void {
    this.onConnectedHandlers.add(handler);
    return () => this.onConnectedHandlers.delete(handler);
  }

  onDisconnected(handler: ConnectionHandler): () => void {
    this.onDisconnectedHandlers.add(handler);
    return () => this.onDisconnectedHandlers.delete(handler);
  }

  get connected(): boolean {
    return this.isConnected;
  }
}

// Singleton instance
export const WebSocketService = new WebSocketServiceClass();
