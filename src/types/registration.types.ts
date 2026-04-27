export interface RegistrationData {
  domainAddress: string;
  roomNumber: string;
  userId: string;
}

export interface RegistrationValidationResponse {
  status: number; // 1=success, 0=failure
  userId?: string;
  message?: string;
}
