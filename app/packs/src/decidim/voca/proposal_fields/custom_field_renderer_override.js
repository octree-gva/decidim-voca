import renderBudget from "./render_budget_field";

/**
 * Override the custom fields renderer to add our own custom fields.
 * This is done by using a Facade other the original renderer.
 */
export default class CustomFieldRendererOverride {
  constructor(customFieldsRenderer) {
    if(!customFieldsRenderer){
      throw new Error("customFieldsRenderer is undefined");
    }
    this.renderer = customFieldsRenderer;
    this.rendererDataToXML = this.renderer.dataToXML;
    this.renderer.dataToXML = this.dataToXML.bind(this)
    this.resetForm();
  }

  /**
   * Takes JSON object data, and transform it in a XML document (valid HTML string)
   * This methods uses only dd, dt, and div tags to be compatible with decidim sanitization. 
   * 
   * @param {Object} data 
   * @returns {string} String to save the field and render it in the proposal body without further computation.
   */
  dataToXML(data) {
    // Get budget fields, to be able to customize rendering after
    // original rendering.
    const budgetData = data.filter(({type}) => {
      return type === "budget"
    })
    // Call original renderer
    const $xml =  $(this.rendererDataToXML(data));
    // Customize rendering for the budget fields
    budgetData.forEach(field => {
      const fieldId = field.name;
      const $dd = $xml.find(`dd#${fieldId} > div`);
      $dd.html(renderBudget(field.userData, field))
    })
    return $xml.html();
  }

  /**
   * Defer to CustomFieldsRenderer#fixBuggyFields
   */
  fixBuggyFields() {
    return this.renderer.fixBuggyFields();
  }

  /**
   * Defer to CustomFieldsRenderer#storeData
   */
  storeData() {
    return this.renderer.storeData();
  }
  
  /**
   * Defer to CustomFieldsRenderer#resetForm
   */
  resetForm() {
    return this.renderer.resetForm();
  }

  /**
   * Defer to CustomFieldsRenderer#init
   */
  init($element) {
    return this.renderer.init($element);    
  }
}
