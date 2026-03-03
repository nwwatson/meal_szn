class Accounts::RecipeSharesController < ApplicationController
  before_action :set_recipe

  def index
    @shares = @recipe.recipe_shares.by_sender(Current.user).order(created_at: :desc)
  end

  def create
    @share = @recipe.recipe_shares.new(
      sender: Current.user,
      recipient_email: params[:recipient_email]
    )

    if @share.save
      RecipeShareMailer.invitation(@share).deliver_later
      redirect_to recipe_path(@recipe), notice: "Recipe shared with #{@share.recipient_email}!"
    else
      redirect_to recipe_path(@recipe), alert: @share.errors.full_messages.to_sentence
    end
  end

  private

  def set_recipe
    @recipe = Current.account.recipes.find(params[:recipe_id])
  end
end
