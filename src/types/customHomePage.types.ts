export interface CustomHomePageData {
  catieTvFontColor: string;
  catieTvFontSize: string;
  catieTvFontType: string;
  catieTvType: number; // UIType 1-6
  tvStatus: number;
  tvRadioFlag: number;
}

export interface CustomHomePageApiResponse {
  status: string;
  data?: CustomHomePageApiData;
}

export interface CustomHomePageApiData {
  catieTvFontColor?: string;
  catieTvFontSize?: string;
  catieTvType?: number;
  catieTvFontType?: string;
  tvStatus?: number;
  tvRadioFlag?: number;
}
