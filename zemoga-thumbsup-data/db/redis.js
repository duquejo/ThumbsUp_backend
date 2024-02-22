const Redis = require('ioredis');

module.exports = () => {
  const redis = new Redis({
    port: process.env.redis_port,
    host: process.env.redis_host,
    username: process.env.redis_username,
    password: process.env.redis_password,
    connectTimeout: 10000,
    lazyConnect: true,
    keepAlive: 1000,
    retryStrategy(times) {
      console.log('Retrying connection');
      const delay = Math.min(times * 50, 2000);
      return delay;
    }
  });
  return redis;
}