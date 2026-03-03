class Accounts::MembershipsController < ApplicationController
  def show
    if Current.user.owner?
      redirect_to members_path, alert: "Account owners cannot leave. Transfer ownership first."
      return
    end

    @recipes = Current.account.recipes.order(:title)
  end

  def destroy
    if Current.user.owner?
      redirect_to members_path, alert: "Account owners cannot leave. Transfer ownership first."
      return
    end

    recipe_ids = params[:recipe_ids] || []

    ActiveRecord::Base.transaction do
      # Create pending recipe transfers for selected recipes
      recipe_ids.each do |recipe_id|
        recipe = Current.account.recipes.find_by(id: recipe_id)
        next unless recipe

        PendingRecipeTransfer.create!(
          identity: Current.identity,
          source_recipe: recipe
        )
      end

      # Deactivate user (terminates sessions, clears identity link)
      Current.user.deactivate
    end

    # Clear the session cookie since sessions were terminated
    cookies.delete(:session_token)
    redirect_to new_signup_path, notice: "You have left the account. Create a new account to continue, and your selected recipes will be transferred."
  end
end
