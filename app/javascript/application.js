import { Turbo } from "@hotwired/turbo-rails"
import "chartkick"
import "Chart.bundle"
import "controllers"

Turbo.StreamActions.redirect = function () {
  Turbo.visit(this.target)
}
