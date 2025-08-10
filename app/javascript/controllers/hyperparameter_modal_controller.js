import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Add ESC key listener for closing modal
    this.handleEscape = this.handleEscape.bind(this)
    document.addEventListener('keydown', this.handleEscape)
  }

  disconnect() {
    document.removeEventListener('keydown', this.handleEscape)
  }

  open(event) {
    event.preventDefault()
    const modal = document.getElementById('hyperparameter-modal')
    if (modal) {
      modal.classList.remove('hidden')
      document.body.style.overflow = 'hidden' // Prevent background scrolling
    }
  }

  close(event) {
    if (event) event.preventDefault()
    const modal = document.getElementById('hyperparameter-modal')
    if (modal) {
      modal.classList.add('hidden')
      document.body.style.overflow = '' // Restore scrolling
    }
  }

  handleEscape(event) {
    if (event.key === 'Escape') {
      this.close()
    }
  }

  // Close modal when clicking outside
  closeOnBackground(event) {
    if (event.target.id === 'hyperparameter-modal') {
      this.close()
    }
  }
}