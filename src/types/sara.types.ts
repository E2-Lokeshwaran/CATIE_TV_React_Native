export interface SaraAlertData {
  isPresent: boolean;
  flash: number; // 0=no flash, 1=flash
  flashColor: string;
  borderColor: string;
  borderWidth: number;
  audioLocalPath: string;
  hasAudio: boolean;
  header: SaraStyleBlock;
  footer: SaraStyleBlock;
  bodyComponents: BodyTextComponent[];
}

export interface SaraStyleBlock {
  text: string;
  fontSize: number;
  fontColor: string;
  backgroundColor: string;
  textAlign: 'left' | 'center' | 'right';
  fontWeight?: 'normal' | 'bold';
}

export interface BodyTextComponent {
  lineKey: string; // +line1, +line2, etc.
  items: BodyInlineItem[];
}

export interface BodyInlineItem {
  text: string;
  fontSize: number;
  fontColor: string;
  fontWeight?: 'normal' | 'bold';
  fontStyle?: 'normal' | 'italic';
  pointer?: string; // bullet or number
}

export interface SaraAlertApiResponse {
  status?: string;
  saraAlertList?: SaraAlertApiItem[];
}

export interface SaraAlertApiItem {
  flash?: number;
  flashColor?: string;
  borderColor?: string;
  borderWidth?: number;
  audioPath?: string;
  header?: SaraHeaderApiItem;
  footer?: SaraFooterApiItem;
  body?: SaraBodyApiItem;
}

export interface SaraHeaderApiItem {
  headerText?: string;
  fontSize?: number;
  fontColor?: string;
  backgroundColor?: string;
  textAlign?: string;
}

export interface SaraFooterApiItem {
  footerText?: string;
  fontSize?: number;
  fontColor?: string;
  backgroundColor?: string;
  textAlign?: string;
}

export interface SaraBodyApiItem {
  bodyTextList?: SaraBodyTextApiItem[];
}

export interface SaraBodyTextApiItem {
  lineKey?: string;
  bodyIndividualList?: SaraBodyIndividualApiItem[];
}

export interface SaraBodyIndividualApiItem {
  text?: string;
  fontSize?: number;
  fontColor?: string;
  fontWeight?: string;
  fontStyle?: string;
  pointer?: string;
}
