// Artillery processor for dynamic request parameters

// Sample driver IDs (from the dataset)
const DRIVER_IDS = [
  20000589, 20000596, 20000320, 20000337, 20000372,
  20000428, 20000450, 20000464, 20000511, 20000542,
  20000558, 20000603, 20000620, 20000634, 20000641
];

function setRandomDriver(requestParams, context, ee, next) {
  const randomIndex = Math.floor(Math.random() * DRIVER_IDS.length);
  context.vars.randomDriverId = DRIVER_IDS[randomIndex];
  return next();
}

function setRandomPagination(requestParams, context, ee, next) {
  context.vars.randomLimit = Math.floor(Math.random() * 100) + 10; // 10-110
  context.vars.randomOffset = Math.floor(Math.random() * 500); // 0-500
  return next();
}

module.exports = {
  setRandomDriver,
  setRandomPagination
};
