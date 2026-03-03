class RecipeShareMailer < ApplicationMailer
  def invitation(recipe_share)
    @recipe_share = recipe_share
    @recipe = recipe_share.recipe
    @sender = recipe_share.sender
    @share_url = recipe_share_url(token: recipe_share.token)

    mail(
      to: recipe_share.recipient_email,
      subject: "#{@sender.name} shared a recipe with you on MealSzn"
    )
  end
end
