import TrackPlayer, {
  Capability,
  State,
  AppKilledPlaybackBehavior,
} from 'react-native-track-player';
import {ImageCacheService} from '../storage/ImageCacheService';

type AudioPriority = 'sara' | 'narration' | 'radio';

let isSetup = false;
let currentPriority: AudioPriority | null = null;
let radioUrl = '';
let radioName = '';
let onNarrationEnd: (() => void) | null = null;

/**
 * Audio service with priority management.
 * Mirrors NarrationAudioPlayer + RadioPlayerController from Swift.
 *
 * Priority: SARA (highest) > Narration > Radio (lowest)
 */
export const AudioService = {
  /**
   * Initialize TrackPlayer. Call once on app start.
   */
  setup: async () => {
    if (isSetup) {
      return;
    }
    try {
      await TrackPlayer.setupPlayer({
        maxCacheSize: 1024 * 50, // 50MB
      });
      await TrackPlayer.updateOptions({
        android: {
          appKilledPlaybackBehavior:
            AppKilledPlaybackBehavior.StopPlaybackAndRemoveNotification,
        },
        capabilities: [Capability.Play, Capability.Pause, Capability.Stop],
        compactCapabilities: [Capability.Play, Capability.Pause],
      });
      isSetup = true;
    } catch (e) {
      console.warn('[AudioService] Setup error:', e);
    }
  },

  /**
   * Play SARA alert audio (highest priority).
   * Stops narration and radio.
   */
  playSara: async (audioUri: string) => {
    try {
      await TrackPlayer.reset();
      currentPriority = 'sara';
      await TrackPlayer.add([
        {
          id: 'sara',
          url: audioUri,
          title: 'SARA Alert',
          artist: 'CATIE',
        },
      ]);
      await TrackPlayer.play();
      console.log('[AudioService] Playing SARA audio');
    } catch (e) {
      console.warn('[AudioService] SARA play error:', e);
    }
  },

  /**
   * Play narration audio for carousel slide (medium priority).
   * Pauses radio while playing. Resumes radio when done.
   * Mirrors NarrationAudioPlayer.playAudio()
   */
  playNarration: async (
    audioUrl: string,
    onDuration: (durationSeconds: number) => void,
    onEnd: () => void
  ) => {
    if (currentPriority === 'sara') {
      return; // SARA has priority
    }

    try {
      // Download audio first
      const fileName = audioUrl.split('/').pop() ?? `narration_${Date.now()}`;
      let localUri = audioUrl;
      try {
        const cached = await ImageCacheService.audioExists(fileName);
        if (cached) {
          localUri = ImageCacheService.getAudioUri(fileName);
        } else {
          localUri = await ImageCacheService.downloadAudio(fileName, audioUrl);
        }
      } catch {
        // Use remote URL as fallback
      }

      await TrackPlayer.reset();
      currentPriority = 'narration';
      onNarrationEnd = onEnd;

      await TrackPlayer.add([
        {
          id: 'narration',
          url: localUri,
          title: 'Narration',
          artist: 'CATIE',
        },
      ]);

      await TrackPlayer.play();

      // Get duration for carousel timer
      const duration = await TrackPlayer.getDuration();
      if (duration && duration > 0) {
        onDuration(duration);
      }

      console.log('[AudioService] Playing narration');
    } catch (e) {
      console.warn('[AudioService] Narration play error:', e);
      onEnd();
    }
  },

  /**
   * Play radio stream (lowest priority).
   * Mirrors RadioPlayerController.playStream()
   */
  playRadio: async (url: string, name = 'Radio') => {
    radioUrl = url;
    radioName = name;

    if (currentPriority === 'sara' || currentPriority === 'narration') {
      console.log('[AudioService] Radio deferred - higher priority playing');
      return;
    }

    try {
      const state = await TrackPlayer.getState();
      if (state === State.Playing) {
        await TrackPlayer.stop();
      }

      await TrackPlayer.reset();
      currentPriority = 'radio';

      await TrackPlayer.add([
        {
          id: 'radio',
          url,
          title: name,
          artist: 'CATIE Radio',
          isLiveStream: true,
        },
      ]);
      await TrackPlayer.play();
      console.log('[AudioService] Playing radio:', url);
    } catch (e) {
      console.warn('[AudioService] Radio play error:', e);
    }
  },

  /**
   * Resume radio after narration or SARA ends.
   */
  resumeRadio: async () => {
    if (radioUrl) {
      await AudioService.playRadio(radioUrl, radioName);
    }
  },

  /**
   * Stop all audio.
   */
  stopAll: async () => {
    try {
      await TrackPlayer.reset();
      currentPriority = null;
    } catch (e) {
      console.warn('[AudioService] stopAll error:', e);
    }
  },

  stopRadio: async () => {
    if (currentPriority === 'radio') {
      await TrackPlayer.stop();
      currentPriority = null;
    }
  },

  stopNarration: async () => {
    if (currentPriority === 'narration') {
      await TrackPlayer.stop();
      currentPriority = null;
      onNarrationEnd?.();
      onNarrationEnd = null;
    }
  },

  getCurrentPriority: () => currentPriority,
};
