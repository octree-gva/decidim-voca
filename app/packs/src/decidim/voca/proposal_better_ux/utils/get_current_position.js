/**
 * Get current position from browser, trying to get a < 100m accuracy
 * @returns {Promise<GeolocationPosition>}
 */
const getCurrentPosition = async () => {
  let retry = 0;
  let position = null;
  while (!position || (retry < 3 && position.coords.accuracy > 100)) {
    position = await new Promise((resolve, reject) => {
      navigator.geolocation.getCurrentPosition(resolve, reject, {
        enableHighAccuracy: true,
        timeout: 10000,
        maximumAge: 60000,
      });
    });
    retry++;
  }
  return position;
};

export default getCurrentPosition;
