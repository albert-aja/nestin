import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { NestinRole } from './roles.decorator';

export interface AuthenticatedUser {
  id: string;
  email?: string;
  role: NestinRole;
  permissions?: string[];
  accessToken: string;
  isAnonymous: boolean;
}

export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): AuthenticatedUser | undefined => {
    const request = ctx
      .switchToHttp()
      .getRequest<{ user?: AuthenticatedUser }>();
    return request.user;
  },
);
