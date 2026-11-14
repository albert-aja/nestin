import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Request } from 'express';
import { map, Observable } from 'rxjs';

export interface PaginatedResult<T> {
  items: T[];
  page: number;
  limit: number;
  total: number;
  source?: string;
}

function isPaginatedResult(value: unknown): value is PaginatedResult<unknown> {
  return (
    value !== null &&
    typeof value === 'object' &&
    Array.isArray((value as PaginatedResult<unknown>).items) &&
    typeof (value as PaginatedResult<unknown>).total === 'number'
  );
}

@Injectable()
export class ResponseEnvelopeInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const request = context
      .switchToHttp()
      .getRequest<Request & { requestId?: string }>();

    return next.handle().pipe(
      map((payload: unknown) => {
        if (isPaginatedResult(payload)) {
          const totalPages = Math.max(
            1,
            Math.ceil(payload.total / Math.max(1, payload.limit)),
          );
          return {
            success: true,
            data: payload.items,
            meta: {
              page: payload.page,
              limit: payload.limit,
              total: payload.total,
              totalPages,
              ...(payload.source ? { source: payload.source } : {}),
              timestamp: new Date().toISOString(),
              requestId: request.requestId,
            },
          };
        }

        return {
          success: true,
          data: payload,
          meta: {
            timestamp: new Date().toISOString(),
            requestId: request.requestId,
          },
        };
      }),
    );
  }
}
