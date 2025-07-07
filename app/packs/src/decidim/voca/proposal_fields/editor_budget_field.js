import throttle from "lodash.throttle";

/**
 * Register administration field.
 * Used in administration and in front end, on proposal creation and edition.
 */
export default function editorBudgetField() {
  if (!window.fbControls) window.fbControls = new Array();

  window.fbControls.push(function (controlClass) {
    /**
     * Budget field
     * Add line of budget and get a total
     */
    class controlBudgetField extends controlClass {
      static get definition() {
        return {
          icon: "💸",
          i18n: {
            default: "Budget",
          },
          defaultAttrs: {
            currency: {
              label: "Currency",
              value: "€",
              type: "text",
            },
            addLineLabel: {
              label: "Label to add a new line",
              value: "+ new line",
              type: "text",
            },
            totalLabel: {
              label: "Total label",
              value: "Total:",
              type: "text",
            },
          },
        };
      }
      configure() {}

      ensureMinimumLines(value, required) {
        const lines = value?.lines || [];
        if (!required) {
          return lines;
        }
        const hasLines = value?.lines?.length > 0;
        if (!hasLines) {
          return [...lines, { label: "", price: 0, id: `${+new Date()}` }];
        }
        return lines;
      }
      _renderLine() {}

      _currentValue() {
        if (this.__currentValue) return this.__currentValue;
        const { value, userData } = this._config();
        const rawValue = userData ? userData[0] : value;
        try {
          return (this.__currentValue = JSON.parse(
            $(rawValue).find("pre").first().html()
          ));
        } catch (e) {
          return (this.__currentValue = {});
        }
      }

      _config() {
        if (this.__config) return this.__config;
        const {
          value,
          userData,
          name,
          currency = "€",
          addLineLabel = "+ new line",
        } = this.config;
        const { required = false, placeholder = "" } = this.rawConfig;
        return (this.__config = {
          value,
          userData,
          name,
          currency,
          addLineLabel,
          required,
          placeholder,
        });
      }
      /**
       * Get the DOMElements that have handler subscribed
       * @returns {Array<DOMElement>} The DOMElement 
       */
      _handlers() {
        if (this.__handlers) return this.__handlers;
        return (this.__handlers = []);
      }

      _addHandler(handler) {
        this._handlers().push(handler);
        return this;
      }

      _clearHandlers() {
        this._handlers().forEach((h) => $(h).off());
        this.__handlers = [];
        return this;
      }

      /**
       * Button to add a new budget line. 
       * @returns {DOMElement} The add line button element.
       */
      _renderAddLineBtn(data) {
        const { addLineLabel, name } = this._config();
        const addLine = this.markup("button", addLineLabel, {
          class:
            "formBuilder__budgetField-addLine button button__xs button__secondary",
        });
        $(addLine).on("click", (evt) => {
          evt.preventDefault();
          $(`#${name}-container`).html(
            this._reRender({
              ...data,
              lines: [
                ...data.lines,
                { label: "", price: 0, id: `${+new Date()}` },
              ],
            })
          );
          $(`#${name}-container .formBuilder__budgetField-label`)
            .last()
            .trigger("focus");
          return false;
        });
        this._addHandler(addLine);
        return addLine;
      }

      /**
       * Render a label input field.
       * This field is always required.
       * @returns {DOMElement} The label input field element.
       */
      _renderLineLabelField(line, index, data) {
        const { name, placeholder } = this._config();
        const inputField = this.markup("input", undefined, {
          class: "formBuilder__budgetField-label",
          type: "text",
          name: `${name}-input[${index}][label]`,
          value: line.label || "",
          placeholder: placeholder,
          required: true,
        });
        $(inputField).on(
          "keyup",
          throttle(function (evt) {
            const newValue = evt.target.value;
            line.label = newValue;
            $(`input#${name}`).val(JSON.stringify(data, null, 2));
          }, 250)
        );
        this._addHandler(inputField);
        return inputField;
      }

      /**
       * Render a price input field, made of:
       * 1. Input field
       * 2. Currency label
       * 
       * This field is always required.
       * @returns {DOMElement} The price input field element.
       */
      _renderLinePriceField(line, index, data) {
        const { currency, name } = this._config();
        const priceField = this.markup("input", undefined, {
          class: "input-group-field formBuilder__budgetField-price",
          required: true,
          type: "number",
          name: `${name}-input[${index}][label]`,
          value: line.price || "",
        });

        // Update price value on change.
        $(priceField).on(
          "keyup",
          throttle(function (evt) {
            const newValue = evt.target.value;
            line.price = parseInt(newValue, 10);
            $(`input#${name}`).val(JSON.stringify(data, null, 2));
          }, 250)
        );
        this._addHandler(priceField);
        // Return an input group with price field and currency label
        return this.markup(
          "div",
          [
            priceField,
            this.markup("span", currency, {
              class: "input-group-label",
            }),
          ],
          { class: "input-group formBuilder__budgetField-priceGroup" }
        );
      }

      /**
       * Render a remove line button.
       * If the form is required, the button is disabled if the form has only one line.
       * @returns {DOMElement} The remove line button element.
       */
      _renderRemoveLineBtn(line, index, data) {
        const { name, required } = this._config();
        const canRemove = data.lines.length > 1 || !required;
        const removeLine = this.markup("a", "X", {
          class:
            "button button__xs button__secondary formBuilder__budgetField-removeLine",
          tabIndex: -1,
          disabled: !canRemove,
          role: "button",
        });
        if (canRemove) {
          // Add handle to remove line (else disabled)
          $(removeLine).on("click", (evt) => {
            evt.preventDefault();
            $(`#${name}-container`).html(
              this._reRender({
                ...data,
                lines: data.lines.filter(({ id }) => id !== line.id),
              })
            );
          });
          this._addHandler(removeLine);
        }
        return removeLine;
      }

      /**
       * Render a line of the form, made of: 
       * 1. Label input
       * 2. Price input + Currency label
       * 3. Remove line button
       * */
      _renderLine(line, index, data) {
        const labelInput = this._renderLineLabelField(line, index, data);
        const priceInput = this._renderLinePriceField(line, index, data);
        const removeLine = this._renderRemoveLineBtn(line, index, data);
        return this.markup("div", [labelInput, priceInput, removeLine], {
          class: "formBuilder__budgetField-editor",
        });
      }

      /**
       * Render the fieldset.
       * Used while handling dynamic changes
       * @param {Object} data - The data to render.
       * @returns {DOMElement} The fieldset element.
       */
      _reRender(data = { lines: [] }) {
        const { required } = this._config();
        data.lines = this.ensureMinimumLines(data, required);
        this._clearHandlers();
        const markupLines = data.lines.map((line, index) =>
          this._renderLine(line, index, data)
        );
        return this.markup(
          "div",
          [...markupLines, this._renderAddLineBtn(data)],
          {
            class:
              "formBuilder__budgetField-container clearfix formBuilder__budgetField-form-editor",
          }
        );
      }

      /**
       * Render a hidden input to store the current value.
       * @returns {DOMElement} The hidden input element.
       */
      _renderHiddenInput() {
        const { name } = this._config();
        return this.markup("input", undefined, {
          type: "hidden",
          value: JSON.stringify(this._currentValue()),
          name: `${name}`,
          id: `${name}`,
          class: "formBuilder__budgetField-editor-value",
        });
      }
      /**
       * Render a fieldset with the current form, made of: 
       * 1. Lines
       * 2. Add line button
       * 3. Hidden input to store the current value.
       * @returns {DOMElement} The fieldset element.
       */
      _renderFieldset() {
        const { name } = this._config();
        return this.markup("fieldset", this._reRender(this._currentValue()), {
          id: `${name}-container`,
          class:
            "formBuilder__budgetField-container clearfix formBuilder__budgetField-form-editor",
        });
      }

      /**
       * build a text DOM element, supporting other jquery text form-control's
       * @return DOM Element to be injected into the form.
       */
      build() {
        return (this.input = this.markup(
          "div",
          [this._renderFieldset(), this._renderHiddenInput()],
          {
            class: "formBuilder__budgetField formBuilder--stale",
          }
        ));
      }

      onRender() {
        // Do not render result while editing.
      }
    }

    // register this control for the following types & text subtypes
    controlClass.register("budget", controlBudgetField);
    return controlBudgetField;
  });
}
