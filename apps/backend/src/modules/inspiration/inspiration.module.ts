import { Module } from '@nestjs/common';
import { InspirationAdminController } from './inspiration-admin.controller';
import { InspirationMeController } from './inspiration-me.controller';
import { InspirationNotificationService } from './inspiration-notification.service';
import { InspirationController } from './inspiration.controller';
import { InspirationService } from './inspiration.service';
import { InspirationStore } from './inspiration.store';

@Module({
  controllers: [
    InspirationController,
    InspirationMeController,
    InspirationAdminController,
  ],
  providers: [
    InspirationNotificationService,
    InspirationStore,
    InspirationService,
  ],
  exports: [
    InspirationService,
    InspirationStore,
    InspirationNotificationService,
  ],
})
export class InspirationModule {}
