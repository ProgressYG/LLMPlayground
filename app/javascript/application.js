// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Initialize application
document.addEventListener("DOMContentLoaded", function() {
  // Iteration controls
  const iterationMinus = document.getElementById("iteration-minus")
  const iterationPlus = document.getElementById("iteration-plus")
  const iterationCount = document.getElementById("iteration-count")
  
  if (iterationMinus && iterationPlus && iterationCount) {
    iterationMinus.addEventListener("click", function() {
      const current = parseInt(iterationCount.value)
      if (current > 1) {
        iterationCount.value = current - 1
      }
    })
    
    iterationPlus.addEventListener("click", function() {
      const current = parseInt(iterationCount.value)
      if (current < 10) {
        iterationCount.value = current + 1
      }
    })
    
    iterationCount.addEventListener("change", function() {
      const value = parseInt(this.value)
      if (value < 1) this.value = 1
      if (value > 10) this.value = 10
    })
  }
  
  // Price modal
  const priceBtn = document.getElementById("price-info-btn")
  const priceModal = document.getElementById("price-modal")
  const closeModal = document.getElementById("close-modal")
  
  if (priceBtn && priceModal) {
    priceBtn.addEventListener("click", function() {
      priceModal.classList.remove("hidden")
    })
    
    if (closeModal) {
      closeModal.addEventListener("click", function() {
        priceModal.classList.add("hidden")
      })
    }
    
    // Close on background click
    priceModal.addEventListener("click", function(e) {
      if (e.target === priceModal) {
        priceModal.classList.add("hidden")
      }
    })
    
    // Close on ESC key
    document.addEventListener("keydown", function(e) {
      if (e.key === "Escape" && !priceModal.classList.contains("hidden")) {
        priceModal.classList.add("hidden")
      }
    })
  }
})
