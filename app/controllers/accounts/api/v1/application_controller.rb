class Accounts::Api::V1::ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  before_action :authenticate_with_token!
  before_action :set_account_from_request

  attr_reader :current_token, :current_identity

  private

  def authenticate_with_token!
    authenticate_with_http_token do |token, _options|
      @current_token = Identity::AccessToken.active.find_by(token: token)
      @current_identity = @current_token&.identity
    end

    unless @current_token
      render json: { error: "Invalid or expired token" }, status: :unauthorized
    end
  end

  def set_account_from_request
    @current_account = request.env["meal_szn.account"]

    unless @current_account
      render json: { error: "Account not found" }, status: :not_found
    end
  end

  def require_write_permission!
    unless current_token&.can_write?
      render json: { error: "Write permission required" }, status: :forbidden
    end
  end

  def current_account
    @current_account
  end
end
