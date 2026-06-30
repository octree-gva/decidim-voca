/**
 * Scrolls the questionnaire step to the top
 */

document.addEventListener('DOMContentLoaded', () => {
  const stepDivs = document.querySelectorAll('.answer-questionnaire__step');
  if (stepDivs.length === 0) { return }
  stepDivs.forEach((stepDiv) => {
    const buttons = stepDiv.querySelectorAll('button');

    buttons.forEach((button) => {
      button.addEventListener("click", (event) => {
        event.preventDefault();         
        const content = document.getElementById('content');
        if (content) { content.scrollIntoView() }
      });
    });
  });
});
