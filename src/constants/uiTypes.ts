// UI Type definitions and data fetching rules - mirrors DataFetchingUtility.swift

export enum UIType {
  LandscapeFullContent = 1,   // Landscape: weather + events + status + carousel
  LandscapeClockFocused = 2,  // Landscape: no events, status + carousel
  PortraitFullContent = 3,    // Portrait: weather + events + status + carousel
  PortraitFullCarousel = 4,   // Portrait: full-screen carousel
  LandscapeCarouselOnly = 5,  // Landscape: carousel only wide (21:9)
  PortraitCarouselPadded = 6, // Portrait: carousel padded (9:16)
}

export type DataType = 'weather' | 'events' | 'statusIndicators' | 'radio';

/**
 * Determines if data should be fetched based on current UI type.
 * Direct TypeScript port of DataFetchingUtility.shouldFetchData()
 */
export function shouldFetchData(
  dataType: DataType,
  uiType: number,
  radioFlag = 1
): boolean {
  switch (dataType) {
    case 'weather':
      // Weather always fetched for all UI types
      return true;

    case 'events':
      // Events only for UI types 1 and 3
      return uiType === 1 || uiType === 3;

    case 'statusIndicators':
      // Status indicators for UI types 1, 2, and 3
      return uiType === 1 || uiType === 2 || uiType === 3;

    case 'radio':
      // Radio: always for 1-4, conditional on radioFlag for 5-6
      if (uiType >= 1 && uiType <= 4) {
        return true;
      }
      if (uiType === 5 || uiType === 6) {
        return radioFlag === 1;
      }
      return true; // default for unknown types

    default:
      return true;
  }
}

/**
 * Returns true if the UI type is landscape orientation
 */
export function isLandscape(uiType: number): boolean {
  return uiType === 1 || uiType === 2 || uiType === 5;
}

/**
 * Returns true if the UI type is portrait orientation
 */
export function isPortrait(uiType: number): boolean {
  return uiType === 3 || uiType === 4 || uiType === 6;
}

/**
 * Carousel aspect ratio for each UI type
 */
export function getCarouselAspectRatio(uiType: number): number {
  switch (uiType) {
    case 1:
    case 2:
      return 16 / 9;
    case 3:
    case 6:
      return 9 / 16;
    case 4:
      return 1;
    case 5:
      return 21 / 9;
    default:
      return 16 / 9;
  }
}
