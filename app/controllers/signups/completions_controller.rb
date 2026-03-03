class Signups::CompletionsController < ApplicationController
  disallow_account_scope
  skip_onboarding_redirect
  allow_unauthorized_access

  layout "public"

  before_action :require_authenticated_identity

  def new
    @signup = Signup.new(identity: Current.identity)
  end

  def create
    @signup = Signup.new(
      identity: Current.identity,
      full_name: params[:full_name]
    )

    if (account = @signup.complete)
      process_pending_recipe_share(account)
      redirect_to "/#{account.external_account_id}", notice: "Welcome to your new account!"
    else
      flash.now[:alert] = @signup.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  private

  def require_authenticated_identity
    redirect_to new_session_path unless Current.identity
  end

  def process_pending_recipe_share(account)
    token = session.delete(:pending_share_token)
    return unless token

    share = RecipeShare.active.find_by(token: token)
    return unless share

    recipient_user = Current.identity.users.find_by(account: account, active: true)
    RecipeFork.call(share.recipe, account, shared_by: share.sender_name)
    share.accept!(recipient_user: recipient_user)
  end
end
