module Authentication::ViaMagicLink
  extend ActiveSupport::Concern

  PENDING_AUTH_COOKIE = :pending_authentication_token

  def redirect_to_session_magic_link(identity)
    set_pending_authentication_token(identity.email_address)
    serve_development_magic_link(identity) if Rails.env.development?
    redirect_to session_magic_link_path
  end

  def redirect_to_fake_session_magic_link
    # Create a fake pending token to prevent email enumeration
    set_pending_authentication_token("fake-#{SecureRandom.hex(8)}@example.com")
    redirect_to session_magic_link_path
  end

  def email_address_pending_authentication
    return unless (token = cookies.signed[PENDING_AUTH_COOKIE])
    message_verifier.verify(token, purpose: :pending_authentication)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  def clear_pending_authentication_token
    cookies.delete(PENDING_AUTH_COOKIE)
  end

  private

  def set_pending_authentication_token(email_address)
    token = message_verifier.generate(email_address, purpose: :pending_authentication)
    cookies.signed[PENDING_AUTH_COOKIE] = {
      value: token,
      httponly: true,
      same_site: :lax,
      expires: MagicLink::EXPIRATION_TIME.from_now
    }
  end

  def serve_development_magic_link(identity)
    magic_link = identity.magic_links.active.last
    return unless magic_link

    flash[:magic_link_code] = magic_link.code
    response.headers["X-Magic-Link-Code"] = magic_link.code
  end

  def message_verifier
    Rails.application.message_verifier("authentication")
  end
end
