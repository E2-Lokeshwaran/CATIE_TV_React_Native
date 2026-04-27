import RNFS from 'react-native-fs';
import {getApiClient} from './ApiClient';
import {buildApiUrls} from '../../constants/api';

const LOG_DIR = `${RNFS.CachesDirectoryPath}/DebugLogs`;

/**
 * Reads all log files and pushes them to the server as base64.
 * Mirrors LogHandlingModel.pushLogsToServerusingJson()
 */
export async function pushLogsToServer(
  domain: string,
  roomNumber: string,
  userId: string
): Promise<void> {
  const urls = buildApiUrls(domain, roomNumber, userId);

  try {
    const dirExists = await RNFS.exists(LOG_DIR);
    if (!dirExists) {
      return;
    }

    const files = await RNFS.readDir(LOG_DIR);
    const logFiles = files.filter(f => f.name.endsWith('.log'));

    if (logFiles.length === 0) {
      return;
    }

    // Combine all log files
    let combined = '';
    for (const file of logFiles) {
      const content = await RNFS.readFile(file.path, 'utf8');
      combined += content + '\n';
    }

    // Base64 encode
    const base64Data = Buffer.from(combined).toString('base64');

    const client = getApiClient();
    await client.post(urls.saveLog, {
      roomNumber,
      logFile: base64Data,
    });

    console.log('[LogPush] Logs pushed to server');
  } catch (e) {
    console.warn('[LogPush] Failed to push logs:', e);
  }
}

/**
 * Write a log entry to the local debug log file.
 */
export async function writeLog(message: string): Promise<void> {
  try {
    await RNFS.mkdir(LOG_DIR);
    const logFile = `${LOG_DIR}/debug.log`;
    const timestamp = new Date()
      .toISOString()
      .replace('T', ' ')
      .replace('Z', '');
    const entry = `${timestamp}: ${message}\n`;
    await RNFS.appendFile(logFile, entry, 'utf8');
  } catch {
    // Non-critical logging
  }
}
