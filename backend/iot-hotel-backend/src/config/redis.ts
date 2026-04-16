import config from '../config';

export default {
  host: config.redis.host,
  port: config.redis.port,
  password: config.redis.password,
  db: config.redis.db,
  keyPrefix: config.redis.keyPrefix,
  enabled: config.redis.enabled,
  defaultTTL: config.redis.defaultTTL
};
