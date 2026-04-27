import React, {useEffect} from 'react';
import {View, StyleSheet} from 'react-native';
import {useAppStore} from '../store/appStore';
import {useDataOrchestrator} from '../hooks/useDataOrchestrator';
import {useTimerManager} from '../hooks/useTimerManager';
import {SaraAlertOverlay} from '../components/shared/SaraAlertOverlay';
import {ClockOverlay} from '../components/shared/ClockOverlay';
import {LandscapeType1} from '../components/landscape/LandscapeType1';
import {LandscapeType2} from '../components/landscape/LandscapeType2';
import {LandscapeType5} from '../components/landscape/LandscapeType5';
import {PortraitType3} from '../components/portrait/PortraitType3';
import {PortraitType4} from '../components/portrait/PortraitType4';
import {PortraitType6} from '../components/portrait/PortraitType6';
import {AudioService} from '../services/audio/AudioService';
import {WebSocketService} from '../services/websocket/WebSocketService';
import DeviceInfo from 'react-native-device-info';

/**
 * Home screen - root display screen.
 * Mounts data orchestrator + timer manager.
 * Routes to the correct layout based on uiType from server config.
 *
 * Mirrors MainScreenViewController.swift coordination role.
 */
export function HomeScreen() {
  const {uiType, tvRadioFlag, domainAddress, roomNumber, userId, communicationStatus} =
    useAppStore();

  // Mount data orchestrator - handles all WS + API data flow
  useDataOrchestrator();

  // Mount timer manager - handles all 10+ timers
  useTimerManager(uiType, tvRadioFlag);

  // Configure WebSocket device details getter
  useEffect(() => {
    WebSocketService.configure(
      () => ({
        tvId: roomNumber,
        ipAddr: DeviceInfo.getIpAddressSync?.() ?? '0.0.0.0',
        appVersion: DeviceInfo.getVersion(),
        deviceOsVersion: DeviceInfo.getSystemVersion(),
        deviceType: DeviceInfo.getModel(),
        deviceDatetime: new Date().toLocaleString('en-US', {
          month: '2-digit',
          day: '2-digit',
          year: 'numeric',
          hour: '2-digit',
          minute: '2-digit',
          hour12: true,
        }),
        communicationStatus: communicationStatus ?? '1',
      }),
      () => 1 // tvStatus always 1 when HomeScreen is shown
    );

    // Setup audio
    AudioService.setup();
  }, [roomNumber, communicationStatus]);

  // Render appropriate layout for the current UI type
  const renderLayout = () => {
    switch (uiType) {
      case 1:
        return <LandscapeType1 />;
      case 2:
        return <LandscapeType2 />;
      case 3:
        return <PortraitType3 />;
      case 4:
        return <PortraitType4 />;
      case 5:
        return <LandscapeType5 />;
      case 6:
        return <PortraitType6 />;
      default:
        return <LandscapeType1 />; // Default to type 1
    }
  };

  return (
    <View style={styles.container}>
      {renderLayout()}

      {/* Global overlays - always on top */}
      <SaraAlertOverlay />
      <ClockOverlay />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
  },
});
