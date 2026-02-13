class Accounts::SettingsController < ApplicationController
  def show
    @settings = Current.user.settings
    @account = Current.account
  end

  def update
    if params[:account]
      return update_account_defaults
    end

    @settings = Current.user.settings

    if @settings.update(settings_params)
      redirect_to settings_path, notice: "Settings updated."
    else
      @account = Current.account
      render :show, status: :unprocessable_entity
    end
  end

  private

  def update_account_defaults
    unless Current.user.admin?
      head :forbidden
      return
    end

    @account = Current.account
    if @account.update(account_defaults_params)
      redirect_to settings_path, notice: "Account defaults updated."
    else
      @settings = Current.user.settings
      render :show, status: :unprocessable_entity
    end
  end

  def settings_params
    params.require(:user_settings).permit(:unit_system, :timezone, :email_frequency)
  end

  def account_defaults_params
    params.require(:account).permit(:default_diet_name, :default_daily_calories_target)
  end
end
