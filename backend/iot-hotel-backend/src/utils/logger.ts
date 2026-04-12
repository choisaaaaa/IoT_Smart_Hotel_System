import winston from 'winston';
import path from 'path';

const logDir = process.env.LOG_DIR || './logs';

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp({
      format: 'YYYY-MM-DD HH:mm:ss'
    }),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: 'iot-hotel-backend' },
  transports: [
    new winston.transports.File({
      filename: path.join(logDir, 'error.log'),
      level: 'error'
    }),
    new winston.transports.File({
      filename: path.join(logDir, 'combined.log')
    })
  ]
});

if (process.env.NODE_ENV !== 'production') {
  logger.add(
    new winston.transports.Console({
      format: winston.format.printf(({ timestamp, level, message, ...meta }) => {
        const ts = timestamp || '';
        const metaStr = Object.keys(meta).length > 1
          ? ` ${JSON.stringify(Object.fromEntries(Object.entries(meta).filter(([k]) => k !== 'service')))}`
          : '';
        return `${ts} [${level}] ${message}${metaStr}`;
      })
    })
  );
}

export default logger;
