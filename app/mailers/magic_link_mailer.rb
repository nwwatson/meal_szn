class MagicLinkMailer < ApplicationMailer
  def sign_in_code(magic_link)
    @magic_link = magic_link
    @code = format_code(magic_link.code)
    @identity = magic_link.identity

    mail(
      to: @identity.email_address,
      subject: "Your sign-in code: #{@code}"
    )
  end

  def sign_up_code(magic_link)
    @magic_link = magic_link
    @code = format_code(magic_link.code)
    @identity = magic_link.identity

    mail(
      to: @identity.email_address,
      subject: "Welcome to MealSzn! Your verification code: #{@code}"
    )
  end

  def onboarding_code(magic_link)
    @magic_link = magic_link
    @code = format_code(magic_link.code)
    @identity = magic_link.identity

    mail(
      to: @identity.email_address,
      subject: "Complete your MealSzn setup: #{@code}"
    )
  end

  private

  def format_code(code)
    "#{code[0..2]}-#{code[3..5]}"
  end
end
