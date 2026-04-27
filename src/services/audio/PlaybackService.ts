/**
 * TrackPlayer background service handler.
 * Must be registered in index.js for react-native-track-player.
 */
import TrackPlayer, {Event} from 'react-native-track-player';

export async function PlaybackService() {
  TrackPlayer.addEventListener(Event.RemotePlay, () => TrackPlayer.play());
  TrackPlayer.addEventListener(Event.RemotePause, () => TrackPlayer.pause());
  TrackPlayer.addEventListener(Event.RemoteStop, () => TrackPlayer.stop());

  TrackPlayer.addEventListener(Event.PlaybackTrackChanged, async event => {
    if (event.nextTrack == null) {
      // Track ended - notify AudioService
      console.log('[PlaybackService] Track ended');
    }
  });
}
