/**
 * CATIE TV React Native - Entry Point
 * @format
 */

import {AppRegistry} from 'react-native';
import TrackPlayer from 'react-native-track-player';
import App from './App';
import {name as appName} from './app.json';
import {PlaybackService} from './src/services/audio/PlaybackService';

AppRegistry.registerComponent(appName, () => App);

// Register TrackPlayer background service
TrackPlayer.registerPlaybackService(() => PlaybackService);
