class JoinController < ApplicationController
  disallow_account_scope
  skip_onboarding_redirect
  allow_unauthorized_access

  layout "public"

  before_action :require_authenticated_identity

  def show
    @code = params[:code]
    if @code.present?
      @join_code = Account::JoinCode.find_by(code: normalize_code(@code))
      if @join_code&.active?
        @account = @join_code.account
        @has_existing_account = Current.identity.users.where(active: true).exists?
      end
    end
  end

  def create
    code = normalize_code(params[:code])
    join_code = Account::JoinCode.find_by(code: code)

    unless join_code&.active?
      redirect_to join_path, alert: "Invalid or expired join code."
      return
    end

    account = join_code.account

    # Check if already a member
    if account.users.where(identity: Current.identity, active: true).exists?
      redirect_to "/#{account.external_account_id}", notice: "You are already a member of this account."
      return
    end

    success = join_code.redeem_if do
      # Deactivate any existing account membership
      deactivate_existing_memberships!

      # Create user in target account
      account.users.create!(
        identity: Current.identity,
        name: Current.identity.email_address,
        role: :member,
        verified_at: Time.current
      )

      # Execute any pending recipe transfers
      PendingRecipeTransfer.execute_for(Current.identity, account)

      true
    end

    if success
      redirect_to "/#{account.external_account_id}", notice: "Welcome! You've joined #{account.name}."
    else
      redirect_to join_path, alert: "Unable to join. The join code may have reached its usage limit."
    end
  end

  private

  def require_authenticated_identity
    return if Current.identity

    # Store the join URL so they return here after auth
    session[:return_to] = request.fullpath
    redirect_to new_session_path
  end

  def deactivate_existing_memberships!
    Current.identity.users.where(active: true).find_each(&:deactivate)
  end

  def normalize_code(code)
    code&.gsub(/[-\s]/, "")
  end
end
