/**
 * Invalidate size on:
 * - geocoder-suggest-coordinates.decidim: Suggestion autocomplete
 * - decidim.voca.refresh_map : Trigger by the "Use my location" button
 */
$(() => {
  $("[data-decidim-map]").one("configure.decidim", (_ev, leafletMap) => {
    $("[data-decidim-geocoding]").on(
      "geocoder-suggest-coordinates.decidim",
      () => leafletMap.invalidateSize()
    );

    $("#address_map").on("decidim.voca.refresh_map", (ev, mapConfig) => {
      leafletMap.invalidateSize();
      // Get the current marker of the leafletMap
      const { marker } = mapConfig;
      if (!marker) {
        return;
      }
      // Re-center the map on the marker
      leafletMap.setView([marker.latitude, marker.longitude], 17);
    });
  });
});
