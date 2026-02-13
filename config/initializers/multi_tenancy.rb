# Configure multi-tenant mode via environment variable
# MULTI_TENANT=true enables multiple accounts
# MULTI_TENANT=false (default) runs in single-tenant mode

Rails.application.config.to_prepare do
  Account.multi_tenant = ENV.fetch("MULTI_TENANT", "false") == "true"
end
