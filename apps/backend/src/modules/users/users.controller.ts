import { Body, Controller, Delete, Get, Patch } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  AuthenticatedUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { UsersService } from './users.service';

@ApiTags('users')
@ApiBearerAuth()
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  @ApiOperation({ summary: 'Get authenticated user profile and sync opt-in metadata' })
  getMe(@CurrentUser() user: AuthenticatedUser) {
    return this.usersService.getMyProfile(user);
  }

  @Patch('me')
  @ApiOperation({ summary: 'Update profile preferences or optional sync opt-in flag' })
  updateMe(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: UpdateProfileDto,
  ) {
    return this.usersService.updateMyProfile(user, dto);
  }

  @Delete('me')
  @ApiOperation({
    summary: 'Soft-delete cloud profile without altering local on-device records',
  })
  deleteMe(@CurrentUser() user: AuthenticatedUser) {
    return this.usersService.softDeleteMyProfile(user);
  }
}
