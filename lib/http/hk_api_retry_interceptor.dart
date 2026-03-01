import 'package:PiliPlus/http/constants.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:dio/dio.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class HkApiRetryInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    String apiHKUrl = Pref.apiHKUrl;
    final originalOptions = response.requestOptions;
    if ((originalOptions.method == 'GET') && (apiHKUrl.isNotEmpty)) {
      final data = response.data;
      if (data is Map && ((data['code'] == -404) || (data['code'] == -10403))) {
        try {
          String newUrl;

          if (originalOptions.path.startsWith('http')) {
            final originalUri = Uri.parse(originalOptions.path);

            if (originalUri.host != HttpString.apiBaseUrl) {
              return handler.next(response);
            }

            newUrl = apiHKUrl + originalUri.path;
            if (originalUri.query.isNotEmpty) {
              newUrl += '?${originalUri.query}';
            }
          } else {
            newUrl = apiHKUrl + originalOptions.path;
          }

          final newResponse = await _retryWithNewDomain(
            originalOptions,
            newUrl,
          );
          return handler.resolve(newResponse);
        } catch (e) {
          SmartDialog.showToast(
            '港澳台解析失败 url:${originalOptions.uri} body: ${response.data}',
          );
          return handler.next(response);
        }
      }
    }

    return handler.next(response);
  }

  Future<Response> _retryWithNewDomain(
    RequestOptions originalOptions,
    String newUrl,
  ) async {
    final newOptions = Options(
      method: originalOptions.method,
      sendTimeout: originalOptions.sendTimeout,
      receiveTimeout: originalOptions.receiveTimeout,
      extra: originalOptions.extra,
      headers: originalOptions.headers,
      responseType: originalOptions.responseType,
      contentType: originalOptions.contentType,
      validateStatus: originalOptions.validateStatus,
      receiveDataWhenStatusError: originalOptions.receiveDataWhenStatusError,
      followRedirects: originalOptions.followRedirects,
      maxRedirects: originalOptions.maxRedirects,
      requestEncoder: originalOptions.requestEncoder,
      responseDecoder: originalOptions.responseDecoder,
      listFormat: originalOptions.listFormat,
    );

    return await Request.dio.request(
      newUrl,
      data: originalOptions.data,
      queryParameters: originalOptions.queryParameters,
      options: newOptions,
      cancelToken: originalOptions.cancelToken,
    );
  }
}
