class RecipeSharesController < ApplicationController
  disallow_account_scope
  skip_onboarding_redirect
  allow_unauthenticated_access
  allow_unauthorized_access

  layout "public"

  before_action :set_recipe_share

  def show
    if @recipe_share.accepted?
      render :already_accepted
    elsif @recipe_share.expired?
      render :expired
    end
  end

  def accept
    unless @recipe_share.redeemable?
      redirect_to recipe_share_path(token: @recipe_share.token),
        alert: @recipe_share.expired? ? "This share link has expired." : "This share has already been claimed."
      return
    end

    unless signed_in?
      session[:return_to] = recipe_share_path(token: @recipe_share.token)
      redirect_to new_session_path, notice: "Sign in to add this recipe to your collection."
      return
    end

    target_account = Current.session.identity.accounts.first
    unless target_account
      session[:pending_share_token] = @recipe_share.token
      redirect_to new_signup_path, notice: "Create an account to add this recipe to your collection."
      return
    end

    forked = RecipeFork.call(
      @recipe_share.recipe,
      target_account,
      shared_by: @recipe_share.sender_name
    )

    recipient_user = Current.session.identity.users.find_by(account: target_account, active: true)
    @recipe_share.accept!(recipient_user: recipient_user)

    redirect_to "/#{target_account.external_account_id}/recipes/#{forked.id}",
      notice: "Recipe added to your collection!"
  end

  def decline
    if @recipe_share.redeemable?
      @recipe_share.decline!
    end

    render :declined
  end

  private

  def set_recipe_share
    @recipe_share = RecipeShare.find_by!(token: params[:token])
    @recipe = @recipe_share.recipe
  rescue ActiveRecord::RecordNotFound
    render plain: "Share link not found", status: :not_found
  end
end
