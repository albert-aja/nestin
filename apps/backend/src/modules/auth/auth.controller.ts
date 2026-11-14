import { Body, Controller, Get, Post } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import {
  AuthenticatedUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { AuthService } from './auth.service';
import { PrepareGuestMigrationDto } from './dto/guest-migration-preview.dto';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Public()
  @Get('policy')
  @ApiOperation({
    summary: 'Inspect Nestin guest-first authentication policy (public)',
  })
  getPolicy() {
    return this.authService.getAuthPolicy();
  }

  @Get('session')
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Validate current Supabase JWT and return resolved identity',
  })
  getSession(@CurrentUser() user: AuthenticatedUser) {
    return this.authService.getSessionIdentity(user);
  }

  @Post('guest-migration/prepare')
  @ApiBearerAuth()
  @ApiOperation({
    summary:
      'Link an existing on-device guest UUID to a newly registered Supabase user without uploading personal data',
  })
  prepareGuestMigration(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: PrepareGuestMigrationDto,
  ) {
    return this.authService.prepareGuestMigration(user, dto);
  }
}
