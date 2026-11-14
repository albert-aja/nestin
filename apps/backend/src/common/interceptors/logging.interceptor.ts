import {
  CallHandler,
  ExecutionContext,
  Injectable,
  Logger,
  NestInterceptor,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import { Request, Response } from 'express';
import { Observable, tap } from 'rxjs';

@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  private readonly logger = new Logger('HTTP');

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const http = context.switchToHttp();
    const request = http.getRequest<Request & { requestId?: string }>();
    const response = http.getResponse<Response>();

    const requestIdHeader = request.headers['x-request-id'];
    const requestId =
      typeof requestIdHeader === 'string' && requestIdHeader.trim()
        ? requestIdHeader.trim()
        : randomUUID();

    request.requestId = requestId;
    response.setHeader('x-request-id', requestId);

    const startedAt = Date.now();
    return next.handle().pipe(
      tap({
        next: () => {
          this.logger.log(
            JSON.stringify({
              event: 'http_request',
              method: request.method,
              path: request.originalUrl ?? request.url,
              statusCode: response.statusCode,
              durationMs: Date.now() - startedAt,
              requestId,
            }),
          );
        },
        error: () => {
          this.logger.warn(
            JSON.stringify({
              event: 'http_request_failed',
              method: request.method,
              path: request.originalUrl ?? request.url,
              statusCode: response.statusCode,
              durationMs: Date.now() - startedAt,
              requestId,
            }),
          );
        },
      }),
    );
  }
}
