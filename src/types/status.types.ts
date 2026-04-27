export interface StatusIndicatorItem {
  statusId: string;
  title: string;
  description: string;
  statusFlag: number; // 0=inactive, 1=active
  iconType?: string;
  iconColor?: string;
}

export interface StatusIndicatorApiResponse {
  status?: string;
  statusIndicatorList?: StatusIndicatorApiItem[];
}

export interface StatusIndicatorApiItem {
  statusId?: string;
  title?: string;
  description?: string;
  statusFlag?: number;
  iconType?: string;
  iconColor?: string;
}
