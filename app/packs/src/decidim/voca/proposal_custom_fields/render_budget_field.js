/**
 * Render the budget field in the proposal form.
 * @param {string} value JSON string of the budget field value
 * @param {Object} config Configuration object for the budget field
 * @returns {jQuery} a jquery div object
 */
export default function renderBudget(value, config) {
  let currentValue;
  try {
    currentValue = JSON.parse(value || "{}");
  } catch (e) {
    currentValue = {};
  }
  // Ensure no white line are saved .
  const lines = (currentValue.lines || []).filter(({ label = "" }) => !!label);
  // Add a div container, to be compatible with other formBuilder fields.
  const $container = $("<div />");
  $container.addClass("formBuilder__budgetField-rendered");

  // Render a hidden tag to store current JSON value for
  // edition purpose. (will parse the content to populate form)
  const $dataContainer = $("<pre />");
  $dataContainer.addClass("hidden");
  $dataContainer.html(JSON.stringify({ ...currentValue, lines }, null, 2));
  $container.append($dataContainer);

  // Render a table with the budget
  const $table = $("<table />");
  $table.data("json", value);
  $table.addClass("table stack formBuilder__budgetField-table");
  const $tbody = $("<tbody />");
  const $tfoot = $("<tfoot />");
  // Compute lines and total
  let total = 0;
  lines.forEach((line) => {
    const $line = $("<tr />");
    $line.addClass("formBuilder__budgetField-line");
    const $label = $("<td />").prop("id", line.id);
    $label.addClass(
      "formBuilder__budgetField-cell formBuilder__budgetField-cell--label",
    );
    $label.text(line.label);
    $line.append($label);

    const $price = $("<td />");
    $price.addClass(
      "formBuilder__budgetField-cell formBuilder__budgetField-cell--price",
    );
    $price.append($("<span />").text(line.price));
    $price.append($("<span />").text(` ${config.currency}`));
    $line.append($price);
    total += line.price;
    $tbody.append($line);
  });
  // Add a footer with the total
  $tfoot.append(
    $("<tr/>").append(
      $("<td/>")
        .prop("colspan", 2)
        .addClass(
          "formBuilder__budgetField-cell formBuilder__budgetField-cell--total",
        )
        .append(
          $("<span />")
            .text(config.totalLabel + ` ${total}`)
            .prop("alt", "total"),
        )
        .append($("<span />").text(` ${config.currency}`)),
    ),
  );
  // Compose the table and container
  $table.append($tbody);
  $table.append($tfoot);
  $container.append($table);
  return $container;
}
