import RNFS from 'react-native-fs';

const CACHE_DIR = `${RNFS.DocumentDirectoryPath}/catie_cache`;
const IMAGE_DIR = `${CACHE_DIR}/images`;
const AUDIO_DIR = `${CACHE_DIR}/audio`;

async function ensureDirectories() {
  try {
    await RNFS.mkdir(IMAGE_DIR);
    await RNFS.mkdir(AUDIO_DIR);
  } catch {
    // Directories may already exist
  }
}

/**
 * Manages local file cache for images and audio.
 * Replaces fileDownloader and Core Data blob storage from Swift.
 */
export const ImageCacheService = {
  init: async () => {
    await ensureDirectories();
  },

  getImagePath: (imageName: string): string => {
    const safeName = imageName.replace(/[^a-zA-Z0-9._-]/g, '_');
    return `${IMAGE_DIR}/${safeName}`;
  },

  getImageUri: (imageName: string): string => {
    const safeName = imageName.replace(/[^a-zA-Z0-9._-]/g, '_');
    return `file://${IMAGE_DIR}/${safeName}`;
  },

  getAudioPath: (fileName: string): string => {
    const safeName = fileName.replace(/[^a-zA-Z0-9._-]/g, '_');
    return `${AUDIO_DIR}/${safeName}`;
  },

  getAudioUri: (fileName: string): string => {
    const safeName = fileName.replace(/[^a-zA-Z0-9._-]/g, '_');
    return `file://${AUDIO_DIR}/${safeName}`;
  },

  imageExists: async (imageName: string): Promise<boolean> => {
    try {
      const path = ImageCacheService.getImagePath(imageName);
      return await RNFS.exists(path);
    } catch {
      return false;
    }
  },

  audioExists: async (fileName: string): Promise<boolean> => {
    try {
      const path = ImageCacheService.getAudioPath(fileName);
      return await RNFS.exists(path);
    } catch {
      return false;
    }
  },

  downloadImage: async (
    imageName: string,
    imageUrl: string
  ): Promise<string> => {
    await ensureDirectories();
    const localPath = ImageCacheService.getImagePath(imageName);

    await RNFS.downloadFile({
      fromUrl: imageUrl,
      toFile: localPath,
      // Self-signed cert handling (iOS)
      connectionTimeout: 30000,
      readTimeout: 30000,
    }).promise;

    return `file://${localPath}`;
  },

  downloadAudio: async (
    fileName: string,
    audioUrl: string
  ): Promise<string> => {
    await ensureDirectories();
    const localPath = ImageCacheService.getAudioPath(fileName);

    await RNFS.downloadFile({
      fromUrl: audioUrl,
      toFile: localPath,
      connectionTimeout: 30000,
      readTimeout: 30000,
    }).promise;

    return `file://${localPath}`;
  },

  deleteAllImages: async () => {
    try {
      const exists = await RNFS.exists(IMAGE_DIR);
      if (exists) {
        await RNFS.unlink(IMAGE_DIR);
      }
      await RNFS.mkdir(IMAGE_DIR);
    } catch (e) {
      console.warn('ImageCacheService: deleteAllImages error', e);
    }
  },

  deleteAllAudio: async () => {
    try {
      const exists = await RNFS.exists(AUDIO_DIR);
      if (exists) {
        await RNFS.unlink(AUDIO_DIR);
      }
      await RNFS.mkdir(AUDIO_DIR);
    } catch (e) {
      console.warn('ImageCacheService: deleteAllAudio error', e);
    }
  },

  deleteAll: async () => {
    await ImageCacheService.deleteAllImages();
    await ImageCacheService.deleteAllAudio();
  },
};
