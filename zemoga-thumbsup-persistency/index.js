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
  const keyCelebrities = 'celebrities';

  if( await redis.sismember(`${keyCelebrities}`, id ) === 0 ) {
    return handleError(404, 'Not Found', 'Celebrity not found');
  }

  const pipeline = redis.pipeline();
  
  if( vote === 'up' ) {
    pipeline.hincrby(`${keyCelebrities}:${id}`, 'votes:positive', 1);
  } else {
    pipeline.hincrby(`${keyCelebrities}:${id}`, 'votes:negative', 1);
  }

  pipeline.hget(`${keyCelebrities}:${id}`, 'votes:positive' );
  pipeline.hget(`${keyCelebrities}:${id}`, 'votes:negative' );

  const results = await pipeline.exec();
  const parsedResults = mapPipelineResults(results);
  
  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      id,
      vote,
      results: {
        positive: parsedResults[1],
        negative: parsedResults[2],
      },
    }),
  }
}

const mapPipelineResults = (results) => {
  return results.map( r => r[1])
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