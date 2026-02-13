/**
 * Stimulus controller for managing dynamic nested form fields.
 *
 * Targets:
 *   - target:   the container where new rows are appended
 *   - template: a <template> element whose innerHTML contains the blueprint
 *               (use NEW_RECORD as the placeholder replaced by a timestamp)
 *
 * Actions:
 *   - add:    clones the template, replaces NEW_RECORD, and appends a row
 *   - remove: hides an existing record and sets _destroy, or removes a new one
 *
 * HTML conventions:
 *   - Each row must have the class `.nested-form-wrapper`
 *   - New (unsaved) rows: `data-new-record="true"`
 *   - Persisted rows: include a hidden `_destroy` field
 *   - Auto-increment fields: add `data-sort="true"` to the input
 */
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["target", "template"];

  add(e) {
    e.preventDefault();

    const fragment = this.templateTarget.content.cloneNode(true);
    const content = this.templateTarget.innerHTML.replace(
      /NEW_RECORD/g,
      new Date().getTime().toString(),
    );

    fragment.innerHTML = content;

    const sortField = fragment.querySelector('[data-sort="true"]');

    if (sortField) {
      const wrappers = this.element.getElementsByClassName("nested-form-wrapper");

      const visibleCount = Array.from(wrappers).reduce((count, wrapper) => {
        const style = window.getComputedStyle(wrapper);
        return style.display !== "none" ? count + 1 : count;
      }, 0);

      sortField.value = visibleCount + 1;
    }

    this.targetTarget.insertAdjacentHTML("beforeend", fragment.innerHTML);
  }

  remove(e) {
    e.preventDefault();
    const wrapper = e.target.closest(".nested-form-wrapper");

    if (wrapper.dataset.newRecord === "true") {
      wrapper.remove();
    } else {
      wrapper.style.display = "none";
      const input = wrapper.querySelector("input[name*='_destroy']");
      input.value = "1";
    }
  }
}
