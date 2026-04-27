import {create} from 'zustand';
import {SaraAlertData, BodyTextComponent} from '../types/sara.types';

interface SaraAlertState {
  isPresent: boolean;
  flash: number;
  flashColor: string;
  borderColor: string;
  borderWidth: number;
  audioLocalPath: string;
  hasAudio: boolean;
  headerText: string;
  headerFontSize: number;
  headerFontColor: string;
  headerBgColor: string;
  headerTextAlign: string;
  footerText: string;
  footerFontSize: number;
  footerFontColor: string;
  footerBgColor: string;
  bodyComponents: BodyTextComponent[];
}

interface SaraAlertActions {
  setSaraAlert: (data: SaraAlertData) => void;
  clearSaraAlert: () => void;
}

export const useSaraAlertStore = create<SaraAlertState & SaraAlertActions>(
  set => ({
    isPresent: false,
    flash: 0,
    flashColor: '#FF0000',
    borderColor: '#FF0000',
    borderWidth: 3,
    audioLocalPath: '',
    hasAudio: false,
    headerText: '',
    headerFontSize: 20,
    headerFontColor: '#FFFFFF',
    headerBgColor: '#FF0000',
    headerTextAlign: 'center',
    footerText: '',
    footerFontSize: 16,
    footerFontColor: '#FFFFFF',
    footerBgColor: '#FF0000',
    bodyComponents: [],

    setSaraAlert: data =>
      set({
        isPresent: data.isPresent,
        flash: data.flash,
        flashColor: data.flashColor,
        borderColor: data.borderColor,
        borderWidth: data.borderWidth,
        audioLocalPath: data.audioLocalPath,
        hasAudio: data.hasAudio,
        headerText: data.header.text,
        headerFontSize: data.header.fontSize,
        headerFontColor: data.header.fontColor,
        headerBgColor: data.header.backgroundColor,
        headerTextAlign: data.header.textAlign,
        footerText: data.footer.text,
        footerFontSize: data.footer.fontSize,
        footerFontColor: data.footer.fontColor,
        footerBgColor: data.footer.backgroundColor,
        bodyComponents: data.bodyComponents,
      }),

    clearSaraAlert: () =>
      set({
        isPresent: false,
        audioLocalPath: '',
        hasAudio: false,
        bodyComponents: [],
      }),
  })
);
