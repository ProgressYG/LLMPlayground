import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["temperature", "maxTokens", "topP"]
  
  connect() {
    // Set up listeners for all sliders
    if (this.hasTemperatureTarget) {
      this.temperatureTarget.addEventListener("input", this.updateTemperature.bind(this))
    }
    
    if (this.hasMaxTokensTarget) {
      this.maxTokensTarget.addEventListener("input", this.updateMaxTokens.bind(this))
    }
    
    if (this.hasTopPTarget) {
      this.topPTarget.addEventListener("input", this.updateTopP.bind(this))
    }
    
    // Set up preset buttons
    this.setupPresetButtons()
  }
  
  updateTemperature(event) {
    const value = event.target.value
    document.getElementById("temperature-value").textContent = value
  }
  
  updateMaxTokens(event) {
    const value = event.target.value
    document.getElementById("max-tokens-value").textContent = value
  }
  
  updateTopP(event) {
    const value = event.target.value
    document.getElementById("top-p-value").textContent = value
  }
  
  setupPresetButtons() {
    // Temperature presets
    document.querySelectorAll("#temperature-slider").forEach(slider => {
      const container = slider.closest("div")
      container.querySelectorAll("button[data-value]").forEach(button => {
        button.addEventListener("click", () => {
          const value = button.dataset.value
          slider.value = value
          document.getElementById("temperature-value").textContent = value
        })
      })
    })
    
    // Max tokens presets
    document.querySelectorAll("#max-tokens-slider").forEach(slider => {
      const container = slider.closest("div")
      container.querySelectorAll("button[data-value]").forEach(button => {
        button.addEventListener("click", () => {
          let value = button.dataset.value
          if (value === "max") {
            value = slider.max
          }
          slider.value = value
          document.getElementById("max-tokens-value").textContent = value
        })
      })
    })
    
    // Top P presets
    document.querySelectorAll("#top-p-slider").forEach(slider => {
      const container = slider.closest("div")
      container.querySelectorAll("button[data-value]").forEach(button => {
        button.addEventListener("click", () => {
          const value = button.dataset.value
          slider.value = value
          document.getElementById("top-p-value").textContent = value
        })
      })
    })
  }
}