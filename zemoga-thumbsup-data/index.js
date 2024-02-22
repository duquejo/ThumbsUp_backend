module.exports.handler = async () => {
  const redis = require('./db/redis')();

  const keyCelebrities = 'celebrities';

  const celebrities = await redis.smembers(`${keyCelebrities}`);

  let parsedResults = [];
  if( ! ( celebrities && Array.isArray(celebrities) && celebrities.length > 0) ) {
    return handleResponse(parsedResults);
  }

  const pipeline = redis.pipeline();
  celebrities.forEach((id) => pipeline.hgetall(`${keyCelebrities}:${id}`) );

  const results = await pipeline.exec();
  parsedResults = mapPipelineResults(results);
  
  return handleResponse(parsedResults);
}

const mapPipelineResults = (results) => {
  return results.map( r => {
    const value = r[1];
    return {
        ...value,
        votes: {
          positive: value['votes:positive'],
          negative: value['votes:negative'],
        }
    };
  });
}

const handleResponse = (data) => ({
  statusCode: 200,
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify(data),
});