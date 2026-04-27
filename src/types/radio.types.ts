export interface RadioData {
  radioUrl: string;
  playingStatus: number; // 0=stop, 1=play
  radioName?: string;
}

export interface RadioApiResponse {
  status?: string;
  radioList?: RadioApiItem[];
}

export interface RadioApiItem {
  radioUrl?: string;
  playingStatus?: number;
  radioName?: string;
}
