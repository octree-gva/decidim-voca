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
  }

  get $element() {
    return this.renderer.$element;
  }


  filterByType(data, matchType) {
    return data.filter(({type}) => {
      return type === matchType
    })
  }

  /**
   * Takes JSON object data, and transform it in a XML document (valid HTML string)
   * This methods uses only dd, dt, and div tags to be compatible with decidim sanitization. 
   * 
   * @param {Object} data 
   * @returns {Promise<string>} String to save the field and render it in the proposal body without further computation.
   */
  async dataToXML(data) {
    // Get budget fields, to be able to customize rendering after
    // original rendering.
    const budgetData = this.filterByType(data, "budget");
    const attachFileData = this.filterByType(data, "attachFile");
    await Promise.all(attachFileData.map(async (field) => {
      const {userData, name} = field;
      if(userData && userData.length > 0) {
        return;
      }

      const $input = $(`input[name="${name}"]`);
      if($input.prop("type") === "file") {
        const url = await this.uploadFile(name);
        if(url) {
          field.userData = [url];
          field.value = url;
        }
      }

    }))
    
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

  async uploadFile(inputName) {
    const $input = $(`input[name="${inputName}"]`);
    if(!$input.attr("type") === "file") {
      throw new Error(`input[name="${inputName}"] is not a file input.`);
    }
    const file = $input.prop("files")[0];
    if(!file) {
      console.warn(`input[name="${inputName}"] has no file, skipping upload`);
      return;
    }
    const formData = new FormData();
    formData.append("file", file);
    return await new Promise((resolve, reject) => {
      $.ajax({
          url: "/editor_files",
          type: 'POST',
          cache: false,
          data: formData,
          dataType: "json",
          jsonp: false,
          processData: false,
          contentType: false,
          async: false,
          headers:{ "X-CSRF-Token": this.csrfToken() },
        }).done((resp) => {
          const {url=""} = resp;
          if(!url){
            resolve(null);
          }else {
            resolve(url);
          }
        }).fail(reject);
    });
  }

  csrfToken() {
    return $('meta[name="csrf-token"]').attr("content");
  }

  /**
   * Defer to CustomFieldsRenderer#fixBuggyFields
   */
  fixBuggyFields() {
    return this.renderer.fixBuggyFields();
  }

  /**
   * Overrides CustomFieldsRenderer#storeData to 
   * allow dataToXML to be async.
   */
  async storeData() {
    if (!this.renderer.$element) {
      return false;
    }
    const $form = this.renderer.$element.closest("form");
    const $body = $form.find(`input[name="${this.renderer.$element.data("name")}"]`);
    if ($body.length && this.renderer.instance) {
      this.renderer.spec = this.renderer.instance.userData;
      $body.val(await this.dataToXML(this.renderer.spec));
      this.renderer.$element.data("spec", this.renderer.spec);
    }
    console.log("storeData spec", this.spec, "$body", $body,"$form",$form,"this",this);
    return this;

  }

  /**
   * Defer to CustomFieldsRenderer#init
   */
  init($element) {
    return this.renderer.init($element);    
  }
}
