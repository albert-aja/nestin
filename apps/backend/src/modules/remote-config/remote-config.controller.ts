import { Controller, Get } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Public } from '../../common/decorators/public.decorator';
import { RemoteConfigService } from './remote-config.service';

@ApiTags('remote-config')
@Public()
@Controller('config')
export class RemoteConfigController {
  constructor(private readonly remoteConfigService: RemoteConfigService) {}

  @Get()
  @ApiOperation({
    summary:
      'Retrieve public remote configuration, feature flags, maintenance state, and minimum app version',
  })
  getConfig() {
    return this.remoteConfigService.getPublicConfig();
  }
}
