export enum ErrorKind {
  UNAUTHORIZED = 'UNAUTHORIZED',
  RISK_CONTROL = 'RISK_CONTROL',
  RATE_LIMIT = 'RATE_LIMIT',
  POW_FAILED = 'POW_FAILED',
  NETWORK = 'NETWORK',
  SERVER = 'SERVER',
  CANCELLED = 'CANCELLED',
  UNKNOWN = 'UNKNOWN'
}

export class ApiError extends Error {
  readonly kind: ErrorKind;
  readonly httpStatus: number;
  readonly bizCode: number;

  constructor(kind: ErrorKind, message: string, httpStatus: number = 0, bizCode: number = 0) {
    super(message);
    this.kind = kind;
    this.httpStatus = httpStatus;
    this.bizCode = bizCode;
  }
}
