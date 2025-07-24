/**
 * Get the first proposal form, if not found, return null
 * @returns {jQuery|null}
 */
const getProposalForm = () => {
  const match = $("form.new_proposal,form.edit_proposal").first();
  if (match.length <= 0) {
    return null;
  }
  return match;
};

export default getProposalForm;
