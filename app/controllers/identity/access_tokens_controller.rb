class Identity::AccessTokensController < ApplicationController
  disallow_account_scope
  allow_unauthorized_access

  def index
    @access_tokens = Current.identity.access_tokens.active.order(created_at: :desc)
  end

  def new
    @access_token = Current.identity.access_tokens.build
  end

  def create
    @access_token = Current.identity.access_tokens.build(access_token_params)

    if @access_token.save
      flash[:token] = @access_token.token
      redirect_to identity_access_tokens_path, notice: "Access token created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @access_token = Current.identity.access_tokens.find(params[:id])
    @access_token.revoke!
    redirect_to identity_access_tokens_path, notice: "Access token revoked."
  end

  private

  def access_token_params
    params.require(:access_token).permit(:name, :permission, :expires_at)
  end
end
