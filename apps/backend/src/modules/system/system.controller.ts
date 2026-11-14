import { Controller, Get } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Public } from '../../common/decorators/public.decorator';
import { SystemService } from './system.service';

@ApiTags('system')
@Public()
@Controller('system')
export class SystemController {
  constructor(private readonly systemService: SystemService) {}

  @Get('health')
  @ApiOperation({ summary: 'Liveness and readiness probe' })
  getHealth() {
    return this.systemService.getHealth();
  }

  @Get('status')
  @ApiOperation({
    summary: 'Operational API status and Supabase connectivity diagnostics',
  })
  getStatus() {
    return this.systemService.getStatus();
  }
}
