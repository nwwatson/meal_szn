# frozen_string_literal: true

require "fast_mcp"

FastMcp.mount_in_rails(
  Rails.application,
  name: "meal-szn",
  version: "1.0.0",
  path_prefix: "/mcp",
  localhost_only: false
) do |server|
  Rails.application.config.after_initialize do
    server.register_tools(*ApplicationTool.descendants)
  end
end
