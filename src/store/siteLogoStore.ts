import {create} from 'zustand';

interface SiteLogoState {
  logoLocalPath: string;
  isLoaded: boolean;
}

interface SiteLogoActions {
  setLogo: (localPath: string) => void;
  clearLogo: () => void;
}

export const useSiteLogoStore = create<SiteLogoState & SiteLogoActions>(
  set => ({
    logoLocalPath: '',
    isLoaded: false,

    setLogo: localPath => set({logoLocalPath: localPath, isLoaded: true}),

    clearLogo: () => set({logoLocalPath: '', isLoaded: false}),
  })
);
