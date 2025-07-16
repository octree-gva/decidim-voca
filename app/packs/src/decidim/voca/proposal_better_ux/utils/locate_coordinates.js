/**
 * Reverse geocode coordinates to an address
 * @param {Record<"latitude" | "longitude", number>} coords
 * @returns {Promise<string|null>}
 */
const locateCoordinates = async (coords) => {
  const result = await new Promise((resolve, reject) => {
    $.post(
      "/locate",
      {
        latitude: coords.latitude,
        longitude: coords.longitude,
      },
      (data) => {
        resolve(data);
      },
      "json",
    );
  });
  return result?.address || null;
};

export default locateCoordinates;