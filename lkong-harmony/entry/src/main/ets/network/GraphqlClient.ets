import { ApiError, ErrorKind } from '../model/Models';
import { CookieStore } from '../store/CookieStore';
import { HttpClient, HttpJsonResponse } from './HttpClient';
import { asArray, asRecord, pickString } from './JsonUtils';

const API_URL = 'https://api.lkong.com/api';

export interface GraphqlResult {
  data: Object;
  cookies: string;
}

/**
 * ArkTS 不允许未声明类型的对象字面量，因此显式定义请求体。
 */
interface GraphqlRequestBody {
  operationName: string;
  variables: Object;
  query: string;
}

/**
 * 龙空 GraphQL 客户端。
 *
 * 请求体格式与站点当前实际请求一致：
 * { operationName, variables, query }
 */
export class GraphqlClient {
  private static instance: GraphqlClient = new GraphqlClient();

  static getInstance(): GraphqlClient {
    return GraphqlClient.instance;
  }

  async request(
    operationName: string,
    variables: Object,
    query: string,
    requireAuth: boolean
  ): Promise<GraphqlResult> {
    if (requireAuth && !CookieStore.getInstance().hasCookie()) {
      throw new ApiError(ErrorKind.AUTH, '请先登录。');
    }

    const requestBody: GraphqlRequestBody = {
      operationName: operationName,
      variables: variables,
      query: query
    };
    const payload = JSON.stringify(requestBody);

    const response: HttpJsonResponse = await HttpClient.getInstance().postJson(API_URL, payload);
    let parsed: Record<string, Object> = {};
    try {
      parsed = JSON.parse(response.body) as Record<string, Object>;
    } catch (error) {
      if (response.statusCode !== 200) {
        throw new ApiError(
          ErrorKind.HTTP,
          `接口返回 HTTP ${response.statusCode}`,
          response.statusCode
        );
      }
      throw new ApiError(ErrorKind.PARSE, '接口返回数据无法解析。');
    }

    const errors = asArray(parsed['errors']);
    if (errors.length > 0) {
      const first = asRecord(errors[0]);
      const message = pickString(first, ['message']);
      const normalized = message.toLowerCase();
      if (message.includes('登录') || normalized.includes('login') ||
        message.includes('账号') || message.includes('密码') || message.includes('权限')) {
        throw new ApiError(ErrorKind.AUTH, message.length > 0 ? message : '登录态无效，请重新登录。');
      }
      throw new ApiError(ErrorKind.HTTP, message.length > 0 ? message : '接口返回错误。');
    }

    const data = parsed['data'];
    if (data === undefined || data === null) {
      throw new ApiError(ErrorKind.PARSE, '接口返回数据为空。');
    }

    const result: GraphqlResult = {
      data: data,
      cookies: response.cookies
    };
    return result;
  }
}