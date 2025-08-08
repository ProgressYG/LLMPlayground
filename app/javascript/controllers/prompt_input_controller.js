import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Add keyboard shortcuts
    this.element.addEventListener("keydown", this.handleKeydown.bind(this))
    
    // Auto-resize textarea
    this.element.addEventListener("input", this.autoResize.bind(this))
  }
  
  handleKeydown(event) {
    // Cmd/Ctrl + Enter to execute
    if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
      event.preventDefault()
      document.getElementById("execute-btn").click()
    }
    
    // Cmd/Ctrl + S to save (future feature)
    if ((event.metaKey || event.ctrlKey) && event.key === "s") {
      event.preventDefault()
      console.log("Save prompt (not implemented yet)")
    }
  }
  
  autoResize() {
    // Reset height to recalculate
    this.element.style.height = "auto"
    
    // Set new height based on content
    const newHeight = Math.min(this.element.scrollHeight, 400) // Max 400px
    this.element.style.height = newHeight + "px"
  }
}