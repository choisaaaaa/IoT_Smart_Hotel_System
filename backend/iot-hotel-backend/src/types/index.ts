import { Request, Response } from 'express';

/**
 * 用户认证请求接口
 */
export interface AuthRequest extends Request {
  user?: {
    id: number;
    username: string;
    phone?: string;
    role: string;
    hotel_id: number;
    permissions?: string[];
  };
}

/**
 * 设备信息接口
 */
export interface DeviceInfo {
  id: number;
  deviceId: string;
  hotelId: number;
  status: string;
  auditStatus: string;
}

/**
 * 设备认证请求接口
 */
export interface DeviceAuthRequest extends Request {
  device?: DeviceInfo;
}

/**
 * 组合认证请求接口（用户+设备）
 */
export interface CombinedAuthRequest extends Request {
  user?: AuthRequest['user'];
  device?: DeviceInfo;
}

export interface ApiResponse<T = any> {
  code: number;
  message: string;
  data?: T;
  timestamp: number;
  path?: string;
}

export interface ApiError {
  code: number;
  message: string;
  details?: any;
  stack?: string;
}

export const SUCCESS_CODE = 200;
export const BAD_REQUEST_CODE = 400;
export const UNAUTHORIZED_CODE = 401;
export const FORBIDDEN_CODE = 403;
export const NOT_FOUND_CODE = 404;
export const SERVER_ERROR_CODE = 500;

export function successResponse<T>(data?: T, message = '操作成功'): ApiResponse<T> {
  return {
    code: SUCCESS_CODE,
    message,
    data,
    timestamp: Date.now()
  };
}

export function errorResponse(message = '服务器错误', code = SERVER_ERROR_CODE, details?: any): ApiError {
  return {
    code,
    message,
    details
  };
}

export function notFound(message = '资源不存在'): ApiError {
  return errorResponse(message, NOT_FOUND_CODE);
}

export function badRequest(message = '请求参数错误'): ApiError {
  return errorResponse(message, BAD_REQUEST_CODE);
}

export function unauthorized(message = '未授权'): ApiError {
  return errorResponse(message, UNAUTHORIZED_CODE);
}

export function forbidden(message = '禁止访问'): ApiError {
  return errorResponse(message, FORBIDDEN_CODE);
}

export function serverError(message = '服务器错误'): ApiError {
  return errorResponse(message, SERVER_ERROR_CODE);
}

export function sendSuccess<T>(res: Response, data?: T, message = '操作成功'): Response {
  return res.status(200).json(successResponse(data, message));
}

export function sendError(res: Response, error: ApiError): Response {
  return res.status(error.code || 500).json({
    code: error.code,
    message: error.message,
    details: error.details,
    timestamp: Date.now()
  });
}
