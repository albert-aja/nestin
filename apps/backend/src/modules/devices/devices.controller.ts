import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  AuthenticatedUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { RegisterDeviceDto } from './dto/register-device.dto';
import { DevicesService } from './devices.service';

@ApiTags('devices')
@ApiBearerAuth()
@Controller('devices')
export class DevicesController {
  constructor(private readonly devicesService: DevicesService) {}

  @Get()
  @ApiOperation({ summary: 'List active registered devices for current user' })
  listDevices(@CurrentUser() user: AuthenticatedUser) {
    return this.devicesService.listDevices(user);
  }

  @Post('register')
  @ApiOperation({
    summary: 'Register or refresh device identity and optional push token',
  })
  registerDevice(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: RegisterDeviceDto,
  ) {
    return this.devicesService.registerOrUpdateDevice(user, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Soft-revoke a registered device' })
  revokeDevice(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) deviceId: string,
  ) {
    return this.devicesService.revokeDevice(user, deviceId);
  }
}
