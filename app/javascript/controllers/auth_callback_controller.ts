import { Controller } from "@hotwired/stimulus"

// Controller for auth success page
// Displays request_id for openclaw to poll /api/v1/auth/token endpoint
export default class extends Controller<HTMLElement> {
  static values = {
    requestId: String
  }

  declare readonly requestIdValue: string

  connect(): void {
    // Display success state with request_id
    // Openclaw polls /api/v1/auth/token?request_id=xxx to retrieve token
    console.log(`Authorization completed for request: ${this.requestIdValue}`)
  }
}
