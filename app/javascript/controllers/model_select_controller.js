import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.addEventListener("change", this.updateMaxTokens.bind(this))
  }
  
  updateMaxTokens(event) {
    const selectedOption = event.target.selectedOptions[0]
    if (selectedOption && selectedOption.dataset.maxTokens) {
      const maxTokens = parseInt(selectedOption.dataset.maxTokens)
      const slider = document.getElementById("max-tokens-slider")
      const limitSpan = document.getElementById("max-tokens-limit")
      
      // Update slider max value
      slider.max = maxTokens
      
      // Update display
      limitSpan.textContent = maxTokens
      
      // If current value exceeds new max, adjust it
      if (parseInt(slider.value) > maxTokens) {
        slider.value = maxTokens
        document.getElementById("max-tokens-value").textContent = maxTokens
      }
    }
  }
}