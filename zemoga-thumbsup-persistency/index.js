module.exports.handler = async (event) => {

  if( !event.body || event.body === '' ) {
    return handleError(400, 'Bad Request', 'Empty body');
  }

  const payload = JSON.parse(event.body);

  if( ! (payload.id && payload.vote ) ) {
    return handleError(400, 'Bad Request', 'The ID or vote parameter are missing');
  }

  if( ! ['positive', 'negative'].includes(payload.vote) ) {
    return handleError(400, 'Bad Request', 'The valid vote values are \'positive\' or \'negative\'');
  }

  const redis = require('./db/redis')();

  const { id, vote } = payload;
  const strId = String(id);
  const keyCelebrities = 'celebrities';

  if( await redis.sismember(`${keyCelebrities}`, strId ) === 0 ) {
    return handleError(404, 'Not Found', 'Celebrity not found');
  }

  const pipeline = redis.pipeline();
  
  if( vote === 'up' ) {
    pipeline.hincrby(`${keyCelebrities}:${strId}`, 'votes:positive', 1);
  } else {
    pipeline.hincrby(`${keyCelebrities}:${strId}`, 'votes:negative', 1);
  }

  pipeline.hget(`${keyCelebrities}:${strId}`, 'votes:positive' );
  pipeline.hget(`${keyCelebrities}:${strId}`, 'votes:negative' );

  await pipeline.exec();

  redis.quit();
  
  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'application/json',
    },
  };
}


const handleError = (status, message, details) => ({
  statusCode: status,
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    status,
    error: message,
    message: details,
  }),
})