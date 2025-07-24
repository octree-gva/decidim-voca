/**
 * Check if we are loading current location
 * @param {jQuery} $button
 * @returns {boolean}
 */
export const isLoading = ($button) => {
  return $button.is(":disabled");
};

/**
 * Set loading state for a list of fields
 * @param {jQuery[]} $fields
 * @param {boolean} loading
 */
export const setLoading = ($fields, loading) => {
  $fields.forEach(($field) => {
    if (loading) {
      $field.attr("disabled", "disabled");
    } else {
      $field.removeAttr("disabled");
    }
  });
};
