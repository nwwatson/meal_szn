class PwaController < ActionController::Base
  skip_forgery_protection

  def service_worker
    response.headers["Service-Worker-Allowed"] = "/"
    response.headers["Cache-Control"] = "no-cache"
    render template: "pwa/service-worker", formats: [ :js ], layout: false, content_type: "application/javascript"
  end

  def manifest
    render template: "pwa/manifest", layout: false, content_type: "application/manifest+json"
  end
end
