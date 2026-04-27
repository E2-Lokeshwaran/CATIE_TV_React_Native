export interface CarouselSlide {
  imageName: string;
  imageLocalPath: string; // local file:// URI after download
  audioPath: string;
  audioFlag: boolean;
  slotTime: number; // seconds
  carouselType: number; // 0=normal, 1=ingage, 2=advertisement
}

export interface CarouselApiResponse {
  status: string;
  slotTime: number;
  startTime: string;
  endTime: string;
  data?: CarouselDataItem[];
}

export interface CarouselDataItem {
  slideDetails?: CarouselSlideDetails;
  scheduleImagePath: string;
  audioPath?: string;
}

export interface CarouselSlideDetails {
  timeout?: number;
  carouselType: number;
  title?: string;
}
