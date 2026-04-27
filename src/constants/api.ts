// API endpoint builders - mirrors API.networkAPI() from DataHelpers.swift

export const buildApiUrls = (
  domain: string,
  roomNumber: string,
  userId: string
) => ({
  weather: `https://${domain}/catie/api/deviceNotification/weatherInformationCatieTv?roomNumber=${roomNumber}`,
  events: `https://${domain}/catie/api/device/event/tvEventList.json?roomNo=${roomNumber}&userId=${userId}`,
  statusIndicator: `https://${domain}/catie/api/statusIndicator/getStatusIndicator?roomNumber=${userId}`,
  carousel: `https://${domain}/catie/appadmin/contentManagement/scheduleTemplateTv.do?roomNumber=${roomNumber}`,
  siteLogo: `https://${domain}/catie/appadmin/appsetting/propertyDetails/getIcon.do?userId=${userId}`,
  imageDownloadBase: `https://${domain}/catie`,
  radio: `https://${domain}/catie/api/device/radio/radioConfiguration?roomNumber=${roomNumber}`,
  scrollMessage: `https://${domain}/catie/api/device/scrollingmessage/message.json?userId=${userId}`,
  saraAlert: `https://${domain}/catie/api/deviceNotificationStatus/saraAlertToTv?roomNumber=${userId}`,
  saveLog: `https://${domain}/catie/saveLog.htm`,
  customHomePage: `https://${domain}/catie/api/deviceConfiguration/getTvInitialConfig?roomNumber=${roomNumber}`,
  clock: `https://${domain}/catie/api/statusIndicator/getClockText?roomNumber=${roomNumber}`,
  wsUrl: `wss://${domain}/webnotification/webnotifier/${roomNumber.toLowerCase()}/notification`,
});
