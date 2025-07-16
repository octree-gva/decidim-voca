import getProposalForm from "./utils/get_proposal_form";
import locateCoordinates from "./utils/locate_coordinates";
import getCurrentPosition from "./utils/get_current_position";
import { isLoading, setLoading } from "./utils/loading";

/**
 * Handler for "Use my location" button
 * @param {Event} e
 */
const findMyLocationHandler = async function (e) {
  e.preventDefault();
  const $button = $(this);
  if (isLoading($button)) {
    return;
  }

  const $addressInputField = $button
    .closest(".input-group")
    .find(".input-group-field");

  setLoading([$button, $addressInputField], true);
  let coordinates = null;
  try {
    let { coords } = await getCurrentPosition();
    const address = await locateCoordinates(coords);
    $addressInputField.val(address?.toString() || "");
    coordinates = [coords.latitude, coords.longitude];
    // Trigger same action as someone clicked on autocomplete suggestion
    $addressInputField.trigger("geocoder-suggest-coordinates.decidim", [
      coordinates,
    ]);
  } finally {
    setLoading([$button, $addressInputField], false);
  }
  // A lot can happen, wait next tick to ro refresh map and enable the fields again.
  setTimeout(() => {
    console.log("coordinates", coordinates);
    if (!coordinates) {
      return;
    }
    // If proposal address map is found, trigger a map reload
    // @see ./map_reload.js
    const $map = $("#address_map");
    if ($map.length > 0) {
      $map.trigger("decidim.voca.refresh_map", {
        marker: { latitude: coordinates[0], longitude: coordinates[1] },
      });
    }
  }, 64);
};

document.addEventListener("DOMContentLoaded", () => {
  const $form = getProposalForm();
  if (!$form) return;
  const $useMyLocationButton = $form.find(".js--use_my_location");
  if (!$useMyLocationButton) {
    return;
  }

  $useMyLocationButton.on("click", findMyLocationHandler);
});
