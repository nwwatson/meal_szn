# frozen_string_literal: true

class ApplicationTool < ActionTool::Base
  McpRequest = Struct.new(:remote_ip)

  authorize do
    token_string = headers["authorization"]&.sub(/\ABearer\s+/i, "")
    next false if token_string.blank?

    access_token = Identity::AccessToken.active.find_by(token: token_string)
    next false unless access_token

    identity = access_token.identity
    next false unless identity

    # Find the user's account (use the first account for MCP)
    user = identity.users.first
    next false unless user

    Current.identity = identity
    Current.account = user.account
    Current.user = user

    access_token.record_usage!(McpRequest.new("mcp"))

    true
  end

  private

  def current_account
    Current.account
  end

  def current_identity
    Current.identity
  end
end
