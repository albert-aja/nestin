import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { configureApp } from './app.setup';

async function bootstrap() {
  const logger = new Logger('Bootstrap');
  const app = await NestFactory.create(AppModule, { bufferLogs: true });
  configureApp(app);

  const configService = app.get(ConfigService);
  const port = configService.get<number>('PORT') ?? 3000;
  await app.listen(port);
  logger.log(`Nestin Backend listening on http://localhost:${port}/api/v1`);
  logger.log(`Swagger docs available at http://localhost:${port}/api/docs`);
}

if (require.main === module) {
  void bootstrap();
}
