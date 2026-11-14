import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request & { requestId?: string }>();

    const isHttpException = exception instanceof HttpException;
    const status = isHttpException
      ? exception.getStatus()
      : HttpStatus.INTERNAL_SERVER_ERROR;

    const rawResponse = isHttpException ? exception.getResponse() : null;
    let message = 'Internal server error';
    let details: unknown;
    let code = `HTTP_${status}`;

    if (typeof rawResponse === 'string') {
      message = rawResponse;
    } else if (rawResponse && typeof rawResponse === 'object') {
      const obj = rawResponse as Record<string, unknown>;
      if (Array.isArray(obj.message)) {
        message = 'Request validation failed';
        details = obj.message;
        code = 'VALIDATION_ERROR';
      } else if (typeof obj.message === 'string') {
        message = obj.message;
      }
      if (typeof obj.code === 'string') {
        code = obj.code;
      }
    } else if (exception instanceof Error && status === HttpStatus.INTERNAL_SERVER_ERROR) {
      this.logger.error(
        JSON.stringify({
          event: 'unhandled_exception',
          path: request.url,
          method: request.method,
          requestId: request.requestId,
          error: exception.message,
        }),
        exception.stack,
      );
    }

    if (status === HttpStatus.UNAUTHORIZED) {
      code = 'UNAUTHORIZED';
    } else if (status === HttpStatus.FORBIDDEN) {
      code = 'FORBIDDEN';
    } else if (status === HttpStatus.NOT_FOUND) {
      code = 'NOT_FOUND';
    } else if (status === HttpStatus.TOO_MANY_REQUESTS) {
      code = 'RATE_LIMITED';
    }

    response.status(status).json({
      success: false,
      error: {
        code,
        message,
        ...(details !== undefined ? { details } : {}),
      },
      meta: {
        timestamp: new Date().toISOString(),
        path: request.url,
        requestId: request.requestId,
      },
    });
  }
}
