# Authentication, Authorization & Security Specification

This document provides a reusable specification for implementing a passwordless multi-tenant authentication and authorization system in Rails applications. It is designed to be used by Claude Code or developers to recreate this architecture.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Database Schema](#database-schema)
3. [Models](#models)
4. [Controllers & Concerns](#controllers--concerns)
5. [User Management Controllers](#user-management-controllers)
6. [Account Management Controllers](#account-management-controllers)
7. [Middleware](#middleware)
8. [Views & UI Flow](#views--ui-flow)
9. [Mailers](#mailers)
10. [Security Measures](#security-measures)
11. [Implementation Checklist](#implementation-checklist)

---

## Architecture Overview

### Core Principles

1. **Passwordless Authentication**: Users authenticate via magic link codes sent to email (no passwords stored)
2. **URL-Based Multi-Tenancy**: Account context extracted from URL path prefix (`/{account_id}/...`)
3. **Separation of Identity and Membership**: Global Identity (email) can have User memberships in multiple Accounts
4. **Role-Based Access Control**: Hierarchical roles (owner > admin > member) at account level
5. **Resource-Level Permissions**: Granular access control on resources via polymorphic Access records
6. **Current Context Pattern**: Thread-safe request context via `ActiveSupport::CurrentAttributes`

### Entity Relationships

```
Identity (global, email-based)
    │
    ├── has_many :sessions (authentication state)
    ├── has_many :access_tokens (API authentication)
    ├── has_many :magic_links (passwordless auth codes)
    └── has_many :users (account memberships)
            │
            └── belongs_to :account (tenant)
                    │
                    ├── has_many :users
                    └── has_many :accesses (polymorphic resource permissions)
```

---

## Database Schema

### Core Tables

```ruby
# db/migrate/xxx_create_identities.rb
create_table :identities, id: :string do |t|
  t.string :email_address, null: false, index: { unique: true }
  t.boolean :staff, default: false, null: false
  t.timestamps
end

# db/migrate/xxx_create_sessions.rb
create_table :sessions, id: :string do |t|
  t.references :identity, null: false, foreign_key: true, type: :string
  t.string :ip_address
  t.string :user_agent
  t.datetime :expires_at, null: false
  t.datetime :last_active_at
  t.timestamps
end
add_index :sessions, :expires_at

# db/migrate/xxx_create_magic_links.rb
create_table :magic_links, id: :string do |t|
  t.references :identity, null: false, foreign_key: true, type: :string
  t.string :code, null: false, index: { unique: true }
  t.integer :purpose, default: 0, null: false  # 0=sign_in, 1=sign_up, 2=onboarding
  t.datetime :expires_at, null: false
  t.timestamps
end

# db/migrate/xxx_create_access_tokens.rb
create_table :access_tokens, id: :string do |t|
  t.references :identity, null: false, foreign_key: true, type: :string
  t.string :token, null: false, index: { unique: true }
  t.string :description
  t.integer :permission, default: 0, null: false  # 0=read, 1=write
  t.datetime :expires_at  # null = never expires
  t.datetime :last_used_at
  t.string :last_used_ip
  t.datetime :revoked_at  # soft revocation
  t.timestamps
end
add_index :access_tokens, :expires_at
add_index :access_tokens, :revoked_at

# db/migrate/xxx_create_accounts.rb
create_table :accounts, id: :string do |t|
  t.bigint :external_account_id, null: false, index: { unique: true }
  t.string :name, null: false
  t.boolean :cancelled, default: false, null: false
  t.timestamps
end

# db/migrate/xxx_create_users.rb
create_table :users, id: :string do |t|
  t.references :account, null: false, foreign_key: true, type: :string
  t.references :identity, foreign_key: true, type: :string  # nullable for system users
  t.string :name, null: false
  t.integer :role, default: 2, null: false  # 0=owner, 1=admin, 2=member, 3=system
  t.boolean :active, default: true, null: false
  t.datetime :verified_at
  t.timestamps
end
add_index :users, [:account_id, :identity_id], unique: true, where: "identity_id IS NOT NULL"

# db/migrate/xxx_create_accesses.rb (for resource-level permissions)
create_table :accesses, id: :string do |t|
  t.references :account, null: false, foreign_key: true, type: :string
  t.references :user, null: false, foreign_key: true, type: :string
  t.references :entity, polymorphic: true, null: false, type: :string
  t.integer :involvement, default: 0, null: false  # 0=access_only, 1=watching
  t.datetime :accessed_at
  t.timestamps
end
add_index :accesses, [:user_id, :entity_type, :entity_id], unique: true
```

### User Management Tables

```ruby
# db/migrate/xxx_create_user_settings.rb
create_table :user_settings, id: :string do |t|
  t.references :user, null: false, foreign_key: true, type: :string
  t.string :timezone
  t.integer :email_frequency, default: 0, null: false  # 0=never, 1=every_4_hours, 2=daily, 3=weekly
  t.timestamps
end

# db/migrate/xxx_create_push_subscriptions.rb
create_table :push_subscriptions, id: :string do |t|
  t.references :account, null: false, foreign_key: true, type: :string
  t.references :user, null: false, foreign_key: true, type: :string
  t.string :endpoint, null: false
  t.string :p256dh_key, null: false
  t.string :auth_key, null: false
  t.string :user_agent
  t.timestamps
end
add_index :push_subscriptions, :endpoint, unique: true

# db/migrate/xxx_create_exports.rb
create_table :exports, id: :string do |t|
  t.references :account, null: false, foreign_key: true, type: :string
  t.references :user, foreign_key: true, type: :string  # nullable for account exports
  t.string :type, null: false  # STI: User::DataExport, Account::Export
  t.integer :status, default: 0, null: false  # 0=pending, 1=processing, 2=completed, 3=failed
  t.timestamps
end
```

### Account Management Tables

```ruby
# db/migrate/xxx_create_account_cancellations.rb
create_table :account_cancellations, id: :string do |t|
  t.references :account, null: false, foreign_key: true, type: :string, index: { unique: true }
  t.references :user, null: false, foreign_key: true, type: :string  # initiated_by
  t.timestamps
end

# db/migrate/xxx_create_account_join_codes.rb
create_table :account_join_codes, id: :string do |t|
  t.references :account, null: false, foreign_key: true, type: :string, index: { unique: true }
  t.string :code, null: false, index: { unique: true }
  t.integer :usage_limit, default: 10_000_000_000, null: false
  t.integer :usage_count, default: 0, null: false
  t.timestamps
end

# db/migrate/xxx_create_account_imports.rb
create_table :account_imports, id: :string do |t|
  t.references :account, null: false, foreign_key: true, type: :string
  t.references :identity, null: false, foreign_key: true, type: :string
  t.integer :status, default: 0, null: false  # 0=pending, 1=processing, 2=completed, 3=failed
  t.timestamps
end
```

---

## Models

### Identity Model

```ruby
# app/models/identity.rb
class Identity < ApplicationRecord
  has_secure_token :transfer_token  # optional: for account transfers

  has_many :sessions, dependent: :destroy
  has_many :magic_links, dependent: :destroy
  has_many :access_tokens, dependent: :destroy
  has_many :users, dependent: :nullify
  has_many :accounts, through: :users

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  # Find identity that has a valid access token for the given HTTP method
  # Returns [identity, access_token] tuple for usage tracking
  def self.find_by_permissable_access_token(token, http_method)
    access_token = AccessToken.active.find_by(token: token)
    return nil unless access_token&.permits?(http_method)
    access_token.identity
  end

  # Alternative method that returns token for usage tracking
  def self.find_with_access_token(token, http_method)
    access_token = AccessToken.active.find_by(token: token)
    return [nil, nil] unless access_token&.permits?(http_method)
    [access_token.identity, access_token]
  end

  def send_magic_link(purpose: :sign_in)
    magic_link = magic_links.create!(purpose: purpose)
    MagicLinkMailer.sign_in_instructions(self, magic_link).deliver_later
    magic_link
  end
end
```

### Session Model

```ruby
# app/models/session.rb
class Session < ApplicationRecord
  EXPIRATION_TIME = 2.weeks
  ACTIVITY_REFRESH_INTERVAL = 1.hour
  IP_CHANGE_POLICY = :warn  # :warn, :block, or :ignore

  belongs_to :identity

  validates :ip_address, presence: true
  validates :user_agent, presence: true
  validates :expires_at, presence: true

  before_validation :set_expiration, on: :create

  scope :active, -> { where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }

  def expired?
    expires_at <= Time.current
  end

  def refresh_activity!
    return if last_active_at && last_active_at > ACTIVITY_REFRESH_INTERVAL.ago
    update!(last_active_at: Time.current, expires_at: EXPIRATION_TIME.from_now)
  end

  # Validates session integrity against current request
  # Returns true if valid, false if suspicious
  def validates_integrity?(request)
    case IP_CHANGE_POLICY
    when :block
      return false if ip_address != request.remote_ip
    when :warn
      if ip_address != request.remote_ip
        Rails.logger.warn "[Session] IP change detected for session #{id}: #{ip_address} -> #{request.remote_ip}"
        # Optional: notify user of new IP access
      end
    end
    true
  end

  private
    def set_expiration
      self.expires_at ||= EXPIRATION_TIME.from_now
      self.last_active_at ||= Time.current
    end
end
```

### MagicLink Model

```ruby
# app/models/magic_link.rb
class MagicLink < ApplicationRecord
  CODE_LENGTH = 6
  EXPIRATION_TIME = 15.minutes

  belongs_to :identity

  enum :purpose, { sign_in: 0, sign_up: 1, onboarding: 2 }

  validates :code, presence: true, uniqueness: true
  validates :expires_at, presence: true

  before_validation :generate_code_and_expiration, on: :create

  scope :active, -> { where("expires_at > ?", Time.current) }
  scope :stale, -> { where("expires_at <= ?", Time.current) }

  def expired?
    expires_at <= Time.current
  end

  def consume(submitted_code)
    return false if expired?
    return false unless ActiveSupport::SecurityUtils.secure_compare(code.upcase, normalize_code(submitted_code))
    destroy
    true
  end

  def self.cleanup
    stale.delete_all
  end

  private
    def generate_code_and_expiration
      self.code ||= generate_unique_code
      self.expires_at ||= EXPIRATION_TIME.from_now
    end

    def generate_unique_code
      loop do
        code = SecureRandom.base32(CODE_LENGTH / 2).first(CODE_LENGTH).upcase
        break code unless MagicLink.exists?(code: code)
      end
    end

    def normalize_code(code)
      code.to_s.upcase.tr("OIL", "011")  # Handle commonly confused characters
    end
end
```

### AccessToken Model

```ruby
# app/models/identity/access_token.rb
class Identity::AccessToken < ApplicationRecord
  self.table_name = "access_tokens"

  belongs_to :identity

  has_secure_token :token

  enum :permission, { read: 0, write: 1 }

  validates :description, presence: true

  scope :active, -> {
    where(revoked_at: nil)
      .where("expires_at IS NULL OR expires_at > ?", Time.current)
  }
  scope :expired, -> { where("expires_at IS NOT NULL AND expires_at <= ?", Time.current) }
  scope :revoked, -> { where.not(revoked_at: nil) }

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def revoked?
    revoked_at.present?
  end

  def active?
    !expired? && !revoked?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def permits?(http_method)
    return false unless active?
    return true if write?
    %w[GET HEAD OPTIONS].include?(http_method.to_s.upcase)
  end

  def record_usage!(request)
    update!(last_used_at: Time.current, last_used_ip: request.remote_ip)
  end

  # Returns masked token for display (e.g., "abc...xyz")
  def masked_token
    return nil if token.blank?
    "#{token[0..3]}...#{token[-4..]}"
  end
end
```

### Account Model

```ruby
# app/models/account.rb
class Account < ApplicationRecord
  include Account::Cancellable
  include Account::Incineratable
  include Account::MultiTenantable

  has_many :users, dependent: :destroy
  has_many :identities, through: :users
  has_many :accesses, dependent: :destroy
  has_many :exports, class_name: "Account::Export", dependent: :destroy
  has_many :imports, class_name: "Account::Import", dependent: :destroy
  has_one :join_code, class_name: "Account::JoinCode", dependent: :destroy

  validates :name, presence: true
  validates :external_account_id, presence: true, uniqueness: true

  before_validation :generate_external_account_id, on: :create
  after_create :create_join_code

  scope :not_cancelled, -> { left_joins(:cancellation).where(account_cancellations: { id: nil }) }
  scope :importing, -> { joins(:imports).merge(Account::Import.where(status: [:pending, :processing])) }

  def slug
    "/#{external_account_id}"
  end

  def importing?
    imports.where(status: [:pending, :processing]).exists?
  end

  def system_user
    users.find_by(role: :system)
  end

  def self.create_with_owner(name:, owner_identity:, owner_name:)
    transaction do
      account = create!(name: name)

      # Create system user
      account.users.create!(
        name: "System",
        role: :system
      )

      # Create owner user
      account.users.create!(
        identity: owner_identity,
        name: owner_name,
        role: :owner,
        verified_at: Time.current
      )

      account
    end
  end

  private
    def generate_external_account_id
      self.external_account_id ||= loop do
        id = SecureRandom.random_number(10_000_000..99_999_999)
        break id unless Account.exists?(external_account_id: id)
      end
    end

    def create_join_code
      build_join_code.save!
    end
end
```

### User Model

```ruby
# app/models/user.rb
class User < ApplicationRecord
  include User::Role
  include User::Accessor  # if using resource-level permissions
  include User::EmailAddressChangeable
  include User::Avatar
  include User::Configurable

  belongs_to :account
  belongs_to :identity, optional: true  # optional for system users

  validates :name, presence: true, length: { maximum: 240 }

  scope :active, -> { where(active: true).where.not(role: :system) }

  def verified?
    verified_at.present?
  end

  def verify
    update!(verified_at: Time.current)
  end

  def deactivate
    transaction do
      # Terminate all sessions for this user's identity in this account
      # This ensures the deactivated user is immediately logged out
      terminate_sessions

      update!(active: false, identity: nil)
    end
  end

  private
    def terminate_sessions
      return unless identity
      # Note: This terminates ALL sessions for the identity, not just this account
      # Consider adding account-scoped session tracking if this is too aggressive
      identity.sessions.destroy_all
    end

  def setup?
    name.present? && name != identity&.email_address
  end
end
```

### User::Role Concern

```ruby
# app/models/user/role.rb
module User::Role
  extend ActiveSupport::Concern

  included do
    enum :role, { owner: 0, admin: 1, member: 2, system: 3 }

    scope :owner, -> { active.where(role: :owner) }
    scope :admin, -> { active.where(role: [:owner, :admin]) }
    scope :member, -> { active.where(role: :member) }
  end

  def admin?
    owner? || read_attribute(:role) == "admin"
  end

  def can_change?(other)
    return true if self == other
    admin? && !other.owner?
  end

  def can_administer?(other)
    return false if self == other
    admin? && !other.owner?
  end
end
```

### User::Accessor Concern (Resource-Level Permissions)

```ruby
# app/models/user/accessor.rb
module User::Accessor
  extend ActiveSupport::Concern

  included do
    has_many :accesses, dependent: :destroy
  end

  # Grant access to a specific entity
  def grant_access_to(entity, involvement: :access_only)
    accesses.find_or_create_by!(account: account, entity: entity) do |access|
      access.involvement = involvement
    end
  end

  # Revoke access from a specific entity
  def revoke_access_from(entity)
    accesses.find_by(entity: entity)&.destroy
  end

  # Check if user has access to a specific entity
  def has_access_to?(entity)
    accesses.exists?(entity: entity)
  end
end
```

### Access Model

```ruby
# app/models/access.rb
class Access < ApplicationRecord
  belongs_to :account
  belongs_to :user
  belongs_to :entity, polymorphic: true

  enum :involvement, { access_only: 0, watching: 1 }

  validates :user_id, uniqueness: { scope: [:entity_type, :entity_id] }

  after_destroy :clean_inaccessible_data

  scope :watching, -> { where(involvement: :watching) }
  scope :for_entity_type, ->(type) { where(entity_type: type) }

  def self.grant_to(users, entity:)
    users.each do |user|
      find_or_create_by!(user: user, entity: entity)
    end
  end

  def self.revoke_from(users)
    where(user: users).destroy_all
  end

  private
    def clean_inaccessible_data
      # Queue job to clean up mentions, notifications, etc.
      CleanInaccessibleDataJob.perform_later(user, entity)
    end
end
```

### User::EmailAddressChangeable Concern

```ruby
# app/models/user/email_address_changeable.rb
module User::EmailAddressChangeable
  extend ActiveSupport::Concern

  TOKEN_EXPIRATION = 30.minutes

  def send_email_address_change_confirmation(new_email_address)
    token = generate_email_change_token(new_email_address)
    UserMailer.email_change_confirmation(self, new_email_address, token).deliver_later
  end

  def change_email_address_using_token(token)
    payload = verify_email_change_token(token)
    return false unless payload

    change_email_address(payload[:new_email_address])
  end

  private
    def generate_email_change_token(new_email_address)
      payload = { user_id: id, old_email: identity.email_address, new_email_address: new_email_address }
      signed_id = SignedGlobalID.create(self, purpose: "change_email_address", expires_in: TOKEN_EXPIRATION)
      Rails.application.message_verifier("email_change").generate(payload, purpose: :email_change, expires_in: TOKEN_EXPIRATION)
    end

    def verify_email_change_token(token)
      Rails.application.message_verifier("email_change").verify(token, purpose: :email_change)
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      nil
    end

    def change_email_address(new_email_address)
      new_identity = Identity.find_or_create_by!(email_address: new_email_address)
      update!(identity: new_identity)
    end
end
```

### User::Avatar Concern

```ruby
# app/models/user/avatar.rb
module User::Avatar
  extend ActiveSupport::Concern

  ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze
  MAX_DIMENSION = 4096

  included do
    has_one_attached :avatar do |attachable|
      attachable.variant :thumb, resize_to_limit: [256, 256]
    end

    validate :validate_avatar, if: -> { avatar.attached? && avatar.new_record? }
  end

  def avatar_attached?
    avatar.attached?
  end

  def avatar_thumbnail
    if avatar.variable?
      avatar.variant(:thumb)
    else
      avatar
    end
  end

  private
    def validate_avatar
      unless ALLOWED_CONTENT_TYPES.include?(avatar.content_type)
        errors.add(:avatar, "must be a JPEG, PNG, GIF, or WebP image")
      end

      if avatar.blob.metadata[:width].to_i > MAX_DIMENSION || avatar.blob.metadata[:height].to_i > MAX_DIMENSION
        errors.add(:avatar, "dimensions must be #{MAX_DIMENSION}x#{MAX_DIMENSION} or smaller")
      end
    end
end
```

### User::Configurable Concern

```ruby
# app/models/user/configurable.rb
module User::Configurable
  extend ActiveSupport::Concern

  included do
    has_one :settings, class_name: "User::Settings", dependent: :destroy
    has_many :push_subscriptions, class_name: "Push::Subscription", dependent: :destroy
    has_many :data_exports, class_name: "User::DataExport", dependent: :destroy

    after_create :create_settings, unless: :system?

    delegate :timezone, to: :settings, allow_nil: true
  end

  private
    def create_settings
      build_settings.save!
    end
end
```

### User::Settings Model

```ruby
# app/models/user/settings.rb
class User::Settings < ApplicationRecord
  belongs_to :user

  enum :email_frequency, { never: 0, every_4_hours: 1, daily: 2, weekly: 3 }

  def timezone
    super.presence || "UTC"
  end
end
```

### Push::Subscription Model

```ruby
# app/models/push/subscription.rb
class Push::Subscription < ApplicationRecord
  include SsrfProtection

  PERMITTED_HOSTS = %w[
    jmt17.google.com
    fcm.googleapis.com
    updates.push.services.mozilla.com
    web.push.apple.com
    notify.windows.com
  ].freeze

  belongs_to :account
  belongs_to :user

  validates :endpoint, presence: true, uniqueness: true
  validates :p256dh_key, presence: true
  validates :auth_key, presence: true
  validate :validate_endpoint_url

  def notification(**params)
    WebPush::Notification.new(
      endpoint: endpoint,
      p256dh: p256dh_key,
      auth: auth_key,
      **params
    )
  end

  private
    def validate_endpoint_url
      uri = URI.parse(endpoint)

      unless uri.scheme == "https"
        errors.add(:endpoint, "must use HTTPS")
        return
      end

      unless PERMITTED_HOSTS.include?(uri.host)
        errors.add(:endpoint, "is not from a permitted push service")
        return
      end

      # SSRF protection: ensure resolved IP is public
      unless SsrfProtection.public_ip?(resolved_endpoint_ip)
        errors.add(:endpoint, "resolves to a private IP address")
      end
    rescue URI::InvalidURIError
      errors.add(:endpoint, "is not a valid URL")
    end

    def resolved_endpoint_ip
      @resolved_endpoint_ip ||= SsrfProtection.resolve_public_ip(URI.parse(endpoint).host)
    rescue
      nil
    end
end
```

### Export Base Model

```ruby
# app/models/export.rb
class Export < ApplicationRecord
  belongs_to :account
  belongs_to :user, optional: true

  has_one_attached :file

  enum :status, { pending: 0, processing: 1, completed: 2, failed: 3 }

  scope :current, -> { where(status: [:pending, :processing]) }
  scope :stale, -> { where("created_at < ?", 24.hours.ago) }

  def build_later
    DataExportJob.perform_later(self)
  end

  def build
    update!(status: :processing)
    generate_export_file
    mark_completed
  rescue => e
    update!(status: :failed)
    raise e
  end

  def mark_completed
    update!(status: :completed)
    notify_user_of_completion
  end

  def self.cleanup
    stale.find_each(&:destroy)
  end

  private
    def generate_export_file
      raise NotImplementedError, "Subclasses must implement generate_export_file"
    end

    def notify_user_of_completion
      ExportMailer.completed(self).deliver_later if user.present?
    end
end
```

### User::DataExport Model

```ruby
# app/models/user/data_export.rb
class User::DataExport < Export
  def filename
    "user-data-export-#{id}.zip"
  end

  private
    def generate_export_file
      Tempfile.create([filename, ".zip"]) do |tempfile|
        build_zip_file(tempfile)
        file.attach(io: File.open(tempfile.path), filename: filename, content_type: "application/zip")
      end
    end

    def build_zip_file(tempfile)
      # Implementation: iterate through user's accessible data
      # and add to ZIP file with JSON metadata
      Zip::File.open(tempfile.path, Zip::File::CREATE) do |zip|
        export_user_profile(zip)
        export_user_content(zip)
      end
    end

    def export_user_profile(zip)
      profile_data = {
        id: user.id,
        name: user.name,
        email: user.identity&.email_address,
        role: user.role,
        created_at: user.created_at,
        verified_at: user.verified_at
      }
      zip.get_output_stream("profile.json") { |f| f.write(JSON.pretty_generate(profile_data)) }
    end

    def export_user_content(zip)
      # Subclass or customize to export application-specific content
    end
end
```

### Account::Cancellable Concern

```ruby
# app/models/account/cancellable.rb
module Account::Cancellable
  extend ActiveSupport::Concern

  included do
    has_one :cancellation, class_name: "Account::Cancellation", dependent: :destroy

    define_callbacks :cancel, :reactivate
  end

  def cancel(initiated_by: Current.user)
    return false unless cancellable? && active?

    with_lock do
      run_callbacks :cancel do
        create_cancellation!(initiated_by: initiated_by)
        AccountMailer.cancelled(self, initiated_by).deliver_later
      end
    end

    true
  end

  def reactivate
    return false unless cancelled?

    with_lock do
      run_callbacks :reactivate do
        cancellation.destroy!
      end
    end

    true
  end

  def cancelled?
    cancellation.present?
  end

  def cancellable?
    Account.accepting_signups?
  end

  def active?
    !cancelled?
  end
end
```

### Account::Incineratable Concern

```ruby
# app/models/account/incineratable.rb
module Account::Incineratable
  extend ActiveSupport::Concern

  INCINERATION_GRACE_PERIOD = 30.days

  included do
    scope :due_for_incineration, -> {
      joins(:cancellation)
        .where("account_cancellations.created_at < ?", INCINERATION_GRACE_PERIOD.ago)
    }

    set_callback :cancel, :after, :schedule_incineration
  end

  def incinerate
    return false unless cancelled?

    transaction do
      destroy!
    end
  end

  def incineration_scheduled_for
    return nil unless cancelled?
    cancellation.created_at + INCINERATION_GRACE_PERIOD
  end

  private
    def schedule_incineration
      AccountIncinerationJob.set(wait: INCINERATION_GRACE_PERIOD).perform_later(id)
    end
end
```

### Account::MultiTenantable Concern

```ruby
# app/models/account/multi_tenantable.rb
module Account::MultiTenantable
  extend ActiveSupport::Concern

  class_methods do
    # Configure via environment variable: MULTI_TENANT=true
    # Single-tenant mode (default): Only one account allowed, first user becomes owner
    # Multi-tenant mode: Multiple accounts allowed, users can create new accounts
    mattr_accessor :multi_tenant, default: false

    def accepting_signups?
      multi_tenant || none?
    end

    # Returns true when this is a fresh install with no accounts yet
    # Used to trigger initial onboarding flow for the first user
    def requires_onboarding?
      !multi_tenant && none?
    end
  end
end
```

Configuration initializer:

```ruby
# config/initializers/multi_tenancy.rb
# Configure multi-tenant mode via environment variable
# MULTI_TENANT=true enables multiple accounts
# MULTI_TENANT=false (default) runs in single-tenant mode
Account.multi_tenant = ENV.fetch("MULTI_TENANT", "false") == "true"
```

### Account::Cancellation Model

```ruby
# app/models/account/cancellation.rb
class Account::Cancellation < ApplicationRecord
  belongs_to :account
  belongs_to :initiated_by, class_name: "User", foreign_key: :user_id

  validates :account_id, uniqueness: true
end
```

### Account::JoinCode Model

```ruby
# app/models/account/join_code.rb
class Account::JoinCode < ApplicationRecord
  CODE_LENGTH = 12
  USAGE_LIMIT_MAX = 10_000_000_000

  belongs_to :account

  validates :code, presence: true, uniqueness: true
  validates :usage_limit, numericality: { greater_than: 0, less_than_or_equal_to: USAGE_LIMIT_MAX }

  before_validation :generate_code, on: :create

  scope :active, -> { where("usage_count < usage_limit") }

  def active?
    usage_count < usage_limit
  end

  def redeem_if
    return false unless active?

    with_lock do
      return false unless active?
      return false unless yield

      increment!(:usage_count)
      true
    end
  end

  def reset
    update!(
      code: generate_code_string,
      usage_count: 0
    )
  end

  def formatted_code
    code.scan(/.{4}/).join("-")
  end

  def join_url
    Rails.application.routes.url_helpers.join_url(code: code, host: Rails.application.config.action_mailer.default_url_options[:host])
  end

  private
    def generate_code
      self.code ||= generate_code_string
    end

    def generate_code_string
      loop do
        code = SecureRandom.base58(CODE_LENGTH)
        break code unless Account::JoinCode.exists?(code: code)
      end
    end
end
```

### Account::Export Model

```ruby
# app/models/account/export.rb
class Account::Export < Export
  def filename
    "account-#{account_id}-export-#{id}.zip"
  end

  private
    def generate_export_file
      Tempfile.create([filename, ".zip"]) do |tempfile|
        build_zip_file(tempfile)
        file.attach(io: File.open(tempfile.path), filename: filename, content_type: "application/zip")
      end
    end

    def build_zip_file(tempfile)
      Zip::File.open(tempfile.path, Zip::File::CREATE) do |zip|
        export_manifest(zip)
        export_account_data(zip)
        export_users(zip)
        # Add application-specific exports here
      end
    end

    def export_manifest(zip)
      manifest = {
        exported_at: Time.current.iso8601,
        account_id: account.id,
        account_name: account.name,
        version: "1.0"
      }
      zip.get_output_stream("manifest.json") { |f| f.write(JSON.pretty_generate(manifest)) }
    end

    def export_account_data(zip)
      account_data = {
        id: account.id,
        name: account.name,
        external_account_id: account.external_account_id,
        created_at: account.created_at
      }
      zip.get_output_stream("account.json") { |f| f.write(JSON.pretty_generate(account_data)) }
    end

    def export_users(zip)
      users_data = account.users.map do |user|
        {
          id: user.id,
          name: user.name,
          email: user.identity&.email_address,
          role: user.role,
          created_at: user.created_at
        }
      end
      zip.get_output_stream("users.json") { |f| f.write(JSON.pretty_generate(users_data)) }
    end
end
```

### Account::Import Model

```ruby
# app/models/account/import.rb
class Account::Import < ApplicationRecord
  belongs_to :account
  belongs_to :identity

  has_one_attached :file

  enum :status, { pending: 0, processing: 1, completed: 2, failed: 3 }

  scope :expired, -> {
    where(status: :completed).where("created_at < ?", 24.hours.ago)
      .or(where(status: :failed).where("created_at < ?", 7.days.ago))
  }

  validates :file, presence: true

  def process_later
    Account::DataImportJob.perform_later(self)
  end

  def process
    update!(status: :processing)

    transaction do
      import_from_zip
      update!(status: :completed)
      AccountMailer.import_completed(self).deliver_later
    end
  rescue => e
    mark_as_failed(e.message)
    raise e
  end

  def mark_as_failed(error_message = nil)
    update!(status: :failed)
    AccountMailer.import_failed(self, error_message).deliver_later
  end

  def cleanup
    return unless failed?
    account.destroy if account.importing?
    destroy
  end

  private
    def import_from_zip
      file.open do |tempfile|
        Zip::File.open(tempfile.path) do |zip|
          import_manifest(zip)
          import_account_data(zip)
          import_users(zip)
          # Add application-specific imports here
        end
      end
    end

    def import_manifest(zip)
      entry = zip.find_entry("manifest.json")
      return unless entry
      JSON.parse(entry.get_input_stream.read)
    end

    def import_account_data(zip)
      entry = zip.find_entry("account.json")
      return unless entry

      data = JSON.parse(entry.get_input_stream.read)
      account.update!(name: data["name"]) if data["name"].present?
    end

    def import_users(zip)
      # Implementation depends on your user import strategy
      # Consider: merge by email, skip existing, etc.
    end
end
```

### Current Context Model

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :session, :identity, :user, :account

  def session=(session)
    super
    self.identity = session&.identity
  end

  def identity=(identity)
    super
    self.user = identity&.users&.find_by(account: account, active: true) if account
  end
end
```

### Signup Form Object

```ruby
# app/models/signup.rb
class Signup
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations::Callbacks

  ACCOUNT_NAME_MAX_LENGTH = 240

  attribute :email_address, :string
  attribute :full_name, :string
  attribute :identity

  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, on: :identity_creation
  validates :full_name, presence: true, length: { maximum: 240 }, on: :completion
  validates :identity, presence: true, on: :completion
  validate :identity_does_not_have_account, on: :completion

  before_validation :normalize_email_address

  def create_identity
    return false unless valid?(:identity_creation)

    self.identity = Identity.find_or_create_by!(email_address: email_address)
    identity.send_magic_link(purpose: :sign_up)
    true
  end

  def complete
    return false unless valid?(:completion)

    # Cap account name length to prevent overflow
    account_name = "#{full_name}'s Account".truncate(ACCOUNT_NAME_MAX_LENGTH)

    account = Account.create!(name: account_name)
    account.users.create!(
      identity: identity,
      name: full_name,
      role: :owner,
      verified_at: Time.current
    )
    account
  end

  private
    def normalize_email_address
      self.email_address = email_address&.strip&.downcase
    end

    # Prevent duplicate account creation for same identity
    def identity_does_not_have_account
      return unless identity
      return unless Account.multi_tenant  # Only check in multi-tenant mode

      if identity.accounts.exists?
        errors.add(:base, "You already have an account. Please sign in instead.")
      end
    end
end
```

### Onboarding Form Object (Initial Setup)

The Onboarding form object handles the first-boot scenario when no accounts exist yet. Unlike regular signup, it:
- Collects organization name (instead of auto-generating it)
- Sets `staff: true` on the Identity (global staff privilege)
- Creates the user with `role: :owner` (account-level ownership)
- Uses database locking to prevent race conditions during first-boot

```ruby
# app/models/onboarding.rb
class Onboarding
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations::Callbacks

  class RaceConditionError < StandardError; end

  attribute :email_address, :string
  attribute :full_name, :string
  attribute :organization_name, :string
  attribute :identity

  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, on: :identity_creation
  validates :full_name, presence: true, length: { maximum: 240 }, on: :completion
  validates :organization_name, presence: true, length: { maximum: 240 }, on: :completion
  validates :identity, presence: true, on: :completion

  before_validation :normalize_email_address

  def create_identity
    return false unless valid?(:identity_creation)

    self.identity = Identity.find_or_create_by!(email_address: email_address)
    identity.send_magic_link(purpose: :onboarding)
    true
  end

  def complete
    return false unless valid?(:completion)
    return false unless Account.requires_onboarding?

    transaction do
      # Re-verify within transaction with advisory lock to prevent race conditions
      # where two users could both attempt to create the first account simultaneously
      Account.connection.execute("SELECT pg_advisory_xact_lock(#{onboarding_lock_key})")

      # Double-check after acquiring lock
      unless Account.none?
        errors.add(:base, "Another user has already completed onboarding")
        raise ActiveRecord::Rollback
      end

      # Mark identity as staff (global privilege)
      identity.update!(staff: true)

      # Create account with provided organization name
      account = Account.create!(name: organization_name)

      # Create system user (for automated actions, imports, scheduled jobs)
      account.users.create!(
        name: "System",
        role: :system
      )

      # Create owner user
      account.users.create!(
        identity: identity,
        name: full_name,
        role: :owner,
        verified_at: Time.current
      )

      account
    end
  end

  private
    def normalize_email_address
      self.email_address = email_address&.strip&.downcase
    end

    def transaction(&block)
      ActiveRecord::Base.transaction(&block)
    end

    # Unique lock key for onboarding race condition prevention
    def onboarding_lock_key
      Zlib.crc32("onboarding_first_account")
    end
end
```

---

## Controllers & Concerns

### Authentication Concern

```ruby
# app/controllers/concerns/authentication.rb
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :redirect_if_requires_onboarding
    before_action :require_account
    before_action :require_authentication

    helper_method :signed_in?
  end

  class_methods do
    def require_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
      before_action :redirect_authenticated_user, **options
    end

    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
      before_action :resume_session_if_present, **options
    end

    def disallow_account_scope(**options)
      skip_before_action :require_account, **options
    end

    def skip_onboarding_redirect(**options)
      skip_before_action :redirect_if_requires_onboarding, **options
    end
  end

  def signed_in?
    Current.session.present?
  end

  private
    # Redirect to onboarding when no accounts exist (first-boot scenario)
    def redirect_if_requires_onboarding
      redirect_to new_onboarding_path if Account.requires_onboarding?
    end

    def require_account
      head :bad_request unless Current.account
    end

    def require_authentication
      resume_session || authenticate_by_bearer_token || request_authentication
    end

    def resume_session
      return false unless (session = find_session_from_cookie)
      return false if session.expired?
      return false unless session.validates_integrity?(request)

      Current.session = session
      session.refresh_activity!
      true
    end

    def resume_session_if_present
      resume_session
    end

    def find_session_from_cookie
      return unless (signed_id = cookies.signed[:session_token])
      Session.active.find_by_signed_id(signed_id)
    end

    def authenticate_by_bearer_token
      return false unless (token = request.headers["Authorization"]&.delete_prefix("Bearer "))

      identity, access_token = Identity.find_with_access_token(token, request.method)
      return false unless identity

      # Record token usage for audit trail
      access_token.record_usage!(request)

      Current.identity = identity
      # IMPORTANT: Set Current.user based on account context for API authorization
      Current.user = identity.users.find_by(account: Current.account, active: true) if Current.account
      true
    end

    def request_authentication
      store_return_url
      redirect_to new_session_path
    end

    def redirect_authenticated_user
      redirect_to root_path if signed_in?
    end

    def start_new_session_for(identity)
      session = identity.sessions.create!(
        user_agent: request.user_agent,
        ip_address: request.remote_ip
      )
      Current.session = session
      set_session_cookie(session)
    end

    def set_session_cookie(session)
      cookies.signed.permanent[:session_token] = {
        value: session.signed_id,
        httponly: true,
        same_site: :lax
      }
    end

    def terminate_session
      Current.session&.destroy
      cookies.delete(:session_token)
      Current.reset
    end

    def store_return_url
      session[:return_to] = request.fullpath if request.get?
    end

    def return_url
      session.delete(:return_to) || root_path
    end
end
```

### Magic Link Authentication Concern

```ruby
# app/controllers/concerns/authentication/via_magic_link.rb
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
```

### Authorization Concern

```ruby
# app/controllers/concerns/authorization.rb
module Authorization
  extend ActiveSupport::Concern

  included do
    before_action :ensure_can_access_account
  end

  class_methods do
    def allow_unauthorized_access(**options)
      skip_before_action :ensure_can_access_account, **options
    end

    def require_access_without_a_user(**options)
      skip_before_action :ensure_can_access_account, **options
      before_action :ensure_account_accessible, **options
    end
  end

  private
    def ensure_can_access_account
      return if Current.account&.active? && Current.user&.active?
      head :forbidden
    end

    def ensure_account_accessible
      return if Current.account && !Current.account.cancelled?
      head :forbidden
    end

    def ensure_admin
      head :forbidden unless Current.user&.admin?
    end

    def ensure_staff
      head :forbidden unless Current.identity&.staff?
    end
end
```

### Authorization::ResourceAccess Concern

Provides resource-level access control using the Access model. Use this to enforce granular permissions on specific resources (e.g., boards, projects).

```ruby
# app/controllers/concerns/authorization/resource_access.rb
module Authorization::ResourceAccess
  extend ActiveSupport::Concern

  included do
    helper_method :can_access?
  end

  private
    # Check if current user can access a resource
    # Admins have access to all resources
    # Other users need explicit access or the resource must be "all access"
    def authorize_access_to(resource)
      return if Current.user&.admin?
      return if resource.respond_to?(:all_access?) && resource.all_access?
      head :forbidden unless Current.user&.has_access_to?(resource)
    end

    # Helper for view-level access checks
    def can_access?(resource)
      return true if Current.user&.admin?
      return true if resource.respond_to?(:all_access?) && resource.all_access?
      Current.user&.has_access_to?(resource)
    end
end

# Usage example:
# class BoardsController < ApplicationController
#   include Authorization::ResourceAccess
#
#   before_action :set_board
#   before_action -> { authorize_access_to(@board) }
# end
```

### Request Forgery Protection Concern

```ruby
# app/controllers/concerns/request_forgery_protection.rb
module RequestForgeryProtection
  extend ActiveSupport::Concern

  included do
    protect_from_forgery with: :exception, unless: -> { should_skip_csrf_check? }
  end

  private
    def should_skip_csrf_check?
      # Skip CSRF for API requests (no Sec-Fetch-Site header) or non-SSL contexts
      request.headers["Sec-Fetch-Site"].blank? || !request.ssl?
    end
end
```

### Sessions Controller

```ruby
# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  include Authentication::ViaMagicLink

  disallow_account_scope
  require_unauthenticated_access only: [:new, :create]
  allow_unauthenticated_access only: :destroy

  layout "public"

  rate_limit to: 10, within: 3.minutes, only: :create

  def new
  end

  def create
    if (identity = Identity.find_by(email_address: params[:email_address]))
      sign_in(identity)
    elsif Account.accepting_signups?
      sign_up
    else
      redirect_to_fake_session_magic_link
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path
  end

  private
    def sign_in(identity)
      identity.send_magic_link(purpose: :sign_in)
      redirect_to_session_magic_link(identity)
    end

    def sign_up
      signup = Signup.new(email_address: params[:email_address])
      if signup.create_identity
        redirect_to_session_magic_link(signup.identity)
      else
        flash.now[:alert] = signup.errors.full_messages.to_sentence
        render :new, status: :unprocessable_entity
      end
    end
end
```

### Magic Links Controller

```ruby
# app/controllers/sessions/magic_links_controller.rb
class Sessions::MagicLinksController < ApplicationController
  include Authentication::ViaMagicLink

  disallow_account_scope
  require_unauthenticated_access

  layout "public"

  rate_limit to: 10, within: 15.minutes, only: :create

  def show
    @email_address = email_address_pending_authentication
    redirect_to new_session_path unless @email_address
  end

  def create
    magic_link = find_valid_magic_link
    pending_email = email_address_pending_authentication

    if magic_link && secure_email_match?(magic_link.identity.email_address, pending_email)
      authenticate_with_magic_link(magic_link)
    else
      flash.now[:alert] = "Invalid or expired code"
      render :show, status: :unprocessable_entity
    end
  end

  private
    def find_valid_magic_link
      return unless params[:code].present?
      MagicLink.active.find_by(code: normalize_code(params[:code]))
    end

    def normalize_code(code)
      code.to_s.upcase.tr("OIL", "011")
    end

    def secure_email_match?(email1, email2)
      ActiveSupport::SecurityUtils.secure_compare(email1.to_s.downcase, email2.to_s.downcase)
    end

    def authenticate_with_magic_link(magic_link)
      identity = magic_link.identity
      purpose = magic_link.purpose

      magic_link.destroy!
      clear_pending_authentication_token
      start_new_session_for(identity)

      case purpose
      when "sign_up"
        redirect_to new_signup_completion_path
      when "onboarding"
        redirect_to new_onboarding_completion_path
      else
        redirect_to return_url
      end
    end
end
```

### Signups Controller

```ruby
# app/controllers/signups_controller.rb
class SignupsController < ApplicationController
  include Authentication::ViaMagicLink

  disallow_account_scope
  require_unauthenticated_access

  layout "public"

  rate_limit to: 10, within: 3.minutes, only: :create

  before_action :ensure_signups_allowed

  def new
  end

  def create
    @signup = Signup.new(email_address: params[:email_address])

    if @signup.create_identity
      redirect_to_session_magic_link(@signup.identity)
    else
      flash.now[:alert] = @signup.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  private
    def ensure_signups_allowed
      redirect_to new_session_path unless Account.accepting_signups?
    end
end
```

### Signup Completions Controller

```ruby
# app/controllers/signups/completions_controller.rb
class Signups::CompletionsController < ApplicationController
  disallow_account_scope
  allow_unauthenticated_access

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
      redirect_to account_root_path(account.external_account_id), notice: "Welcome to your new account!"
    else
      flash.now[:alert] = @signup.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  private
    def require_authenticated_identity
      redirect_to new_session_path unless Current.identity
    end
end
```

### Onboardings Controller (Initial Setup)

Handles the first step of initial onboarding where users enter their email address.

```ruby
# app/controllers/onboardings_controller.rb
class OnboardingsController < ApplicationController
  include Authentication::ViaMagicLink

  disallow_account_scope
  skip_onboarding_redirect
  require_unauthenticated_access

  layout "public"

  rate_limit to: 10, within: 3.minutes, only: :create

  before_action :ensure_onboarding_available

  def new
  end

  def create
    @onboarding = Onboarding.new(email_address: params[:email_address])

    if @onboarding.create_identity
      redirect_to_session_magic_link(@onboarding.identity)
    else
      flash.now[:alert] = @onboarding.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  private
    def ensure_onboarding_available
      redirect_to new_session_path unless Account.requires_onboarding?
    end
end
```

### Onboardings::Completions Controller

Handles the second step of initial onboarding where users enter their name and organization name.

```ruby
# app/controllers/onboardings/completions_controller.rb
class Onboardings::CompletionsController < ApplicationController
  disallow_account_scope
  skip_onboarding_redirect
  allow_unauthenticated_access

  layout "public"

  before_action :require_authenticated_identity
  before_action :ensure_onboarding_available

  def new
    @onboarding = Onboarding.new(identity: Current.identity)
  end

  def create
    @onboarding = Onboarding.new(
      identity: Current.identity,
      full_name: params[:full_name],
      organization_name: params[:organization_name]
    )

    if (account = @onboarding.complete)
      redirect_to account_root_path(account.external_account_id), notice: "Welcome! Your organization is ready."
    else
      flash.now[:alert] = @onboarding.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  private
    def require_authenticated_identity
      redirect_to new_onboarding_path unless Current.identity
    end

    def ensure_onboarding_available
      redirect_to new_session_path unless Account.requires_onboarding?
    end
end
```

### Application Controller

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Authentication
  include Authorization
  include RequestForgeryProtection
end
```

### Identity::AccessTokensController

Allows users to create, view, and revoke their API access tokens.

```ruby
# app/controllers/identity/access_tokens_controller.rb
class Identity::AccessTokensController < ApplicationController
  disallow_account_scope

  before_action :set_access_tokens
  before_action :set_access_token, only: :destroy

  def index
    @tokens = @access_tokens.order(created_at: :desc)
  end

  def new
    @token = @access_tokens.new
  end

  def create
    @token = @access_tokens.new(token_params)

    if @token.save
      # Store the full token in flash for one-time display
      flash[:new_token] = @token.token
      redirect_to identity_access_tokens_path, notice: "Token created successfully. Copy it now - you won't be able to see it again."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @token.revoke!
    redirect_to identity_access_tokens_path, notice: "Token revoked successfully"
  end

  private
    def set_access_tokens
      @access_tokens = Current.identity.access_tokens
    end

    def set_access_token
      @token = @access_tokens.find(params[:id])
    end

    def token_params
      params.require(:access_token).permit(:description, :permission, :expires_at)
    end
end
```

### Identity::SessionsController

Allows users to view and revoke their active sessions across devices.

```ruby
# app/controllers/identity/sessions_controller.rb
class Identity::SessionsController < ApplicationController
  disallow_account_scope

  before_action :set_sessions
  before_action :set_session, only: :destroy

  def index
    @sessions = @sessions.active.order(last_active_at: :desc)
  end

  def destroy
    if @session == Current.session
      redirect_to identity_sessions_path, alert: "Cannot revoke your current session"
    else
      @session.destroy
      redirect_to identity_sessions_path, notice: "Session revoked successfully"
    end
  end

  def destroy_all
    @sessions.active.where.not(id: Current.session.id).destroy_all
    redirect_to identity_sessions_path, notice: "All other sessions have been revoked"
  end

  private
    def set_sessions
      @sessions = Current.identity.sessions
    end

    def set_session
      @session = @sessions.find(params[:id])
    end
end
```

---

## User Management Controllers

These controllers handle common SaaS user management operations: role management, email verification, user onboarding, email address changes, data exports, push notifications, and avatar management.

### Users::RolesController

Allows admins to change user roles within an account.

```ruby
# app/controllers/users/roles_controller.rb
class Users::RolesController < ApplicationController
  before_action :set_user
  before_action :ensure_permission_to_administer_user

  def update
    @user.update!(role_params)
    redirect_to account_settings_path
  end

  private
    def set_user
      @user = Current.account.users.active.find(params[:user_id])
    end

    def ensure_permission_to_administer_user
      head :forbidden unless Current.user.can_administer?(@user)
    end

    def role_params
      { role: params.require(:user)[:role].presence_in(%w[member admin]) || "member" }
    end
end
```

### Users::VerificationsController

Handles email verification for newly invited users.

```ruby
# app/controllers/users/verifications_controller.rb
class Users::VerificationsController < ApplicationController
  layout "public"

  def new
  end

  def create
    Current.user.verify
    redirect_to new_users_join_path
  end
end
```

### Users::JoinsController

Handles user onboarding flow where invited users complete their profile.

```ruby
# app/controllers/users/joins_controller.rb
class Users::JoinsController < ApplicationController
  layout "public"

  def new
  end

  def create
    Current.user.update!(user_params)
    redirect_to landing_path
  end

  private
    def user_params
      params.expect(user: [:name, :avatar])
    end
end
```

### Users::EmailAddressesController

Initiates email address change requests with secure token confirmation.

```ruby
# app/controllers/users/email_addresses_controller.rb
class Users::EmailAddressesController < ApplicationController
  before_action :set_user
  before_action :ensure_can_change_user
  rate_limit to: 5, within: 1.hour, only: :create

  def new
  end

  def create
    identity = Identity.find_by_email_address(new_email_address)

    if identity&.users&.exists?(account: @user.account)
      flash[:alert] = "You already have a user in this account with that email address"
      redirect_to new_user_email_address_path(@user)
    else
      @user.send_email_address_change_confirmation(new_email_address)
      redirect_to @user, notice: "Check your new email address for a confirmation link"
    end
  end

  private
    def set_user
      # Cross-account validation: ensure user belongs to current account
      # and is associated with the current identity
      @user = Current.account.users
        .where(identity: Current.identity)
        .find(params[:user_id])
    end

    def ensure_can_change_user
      head :forbidden unless Current.user.can_change?(@user)
    end

    def new_email_address
      params.expect :email_address
    end
end
```

### Users::EmailAddresses::ConfirmationsController

Confirms email address changes using secure tokens.

```ruby
# app/controllers/users/email_addresses/confirmations_controller.rb
class Users::EmailAddresses::ConfirmationsController < ApplicationController
  allow_unauthenticated_access

  before_action :set_user
  rate_limit to: 5, within: 1.hour, only: :create

  def show
  end

  def create
    if @user.change_email_address_using_token(token)
      terminate_session if Current.session
      start_new_session_for @user.identity

      redirect_to edit_user_url(script_name: @user.account.slug, id: @user)
    else
      render :invalid_token, status: :unprocessable_entity
    end
  end

  private
    def set_user
      @user = Current.account.users.active.find(params[:user_id])
    end

    def token
      params.expect :email_address_token
    end
end
```

### Users::DataExportsController

GDPR-compliant user data export functionality.

```ruby
# app/controllers/users/data_exports_controller.rb
class Users::DataExportsController < ApplicationController
  before_action :set_user
  before_action :ensure_current_user
  before_action :ensure_export_limit_not_exceeded, only: :create
  before_action :set_export, only: :show

  CURRENT_EXPORT_LIMIT = 10

  def show
  end

  def create
    @user.data_exports.create!(account: Current.account).build_later
    redirect_to @user, notice: "Export started. You'll receive an email when it's ready."
  end

  private
    def set_user
      @user = Current.account.users.find(params[:user_id])
    end

    def ensure_current_user
      head :forbidden unless @user == Current.user
    end

    def ensure_export_limit_not_exceeded
      head :too_many_requests if @user.data_exports.current.count >= CURRENT_EXPORT_LIMIT
    end

    def set_export
      @export = @user.data_exports.completed.find_by(id: params[:id])
    end
end
```

### Users::PushSubscriptionsController

Manages web push notification subscriptions.

```ruby
# app/controllers/users/push_subscriptions_controller.rb
class Users::PushSubscriptionsController < ApplicationController
  before_action :set_push_subscriptions

  def index
  end

  def create
    @push_subscriptions.create_with(user_agent: request.user_agent).create_or_find_by!(push_subscription_params)
    head :created
  end

  def destroy
    @push_subscriptions.destroy_by(id: params[:id])
    redirect_to user_push_subscriptions_url
  end

  private
    def set_push_subscriptions
      @push_subscriptions = Current.user.push_subscriptions
    end

    def push_subscription_params
      params.require(:push_subscription).permit(:endpoint, :p256dh_key, :auth_key)
    end
end
```

### Users::AvatarsController

Handles user avatar display and deletion with initials fallback.

```ruby
# app/controllers/users/avatars_controller.rb
class Users::AvatarsController < ApplicationController
  allow_unauthenticated_access only: :show

  before_action :set_user
  before_action :ensure_permission_to_administer_user, only: :destroy

  def show
    if @user.system?
      redirect_to view_context.image_path("system_user.png")
    elsif @user.avatar.attached?
      redirect_to rails_blob_path(@user.avatar_thumbnail, disposition: "inline")
    elsif stale? @user, cache_control: cache_control
      render_initials
    end
  end

  def destroy
    @user.avatar.destroy
    redirect_to @user
  end

  private
    def set_user
      @user = Current.account.users.find(params[:user_id])
    end

    def ensure_permission_to_administer_user
      head :forbidden unless Current.user.can_change?(@user)
    end

    def cache_control
      if @user == Current.user
        {}
      else
        { max_age: 30.minutes, stale_while_revalidate: 1.week }
      end
    end

    def render_initials
      render formats: :svg
    end
end
```

---

## Account Management Controllers

These controllers handle account-level SaaS operations: settings, cancellation, data export/import, and team invitations.

### Account::SettingsController

Manages account configuration and displays user list.

```ruby
# app/controllers/account/settings_controller.rb
class Account::SettingsController < ApplicationController
  before_action :ensure_admin, only: :update
  before_action :set_account

  def show
    @users = @account.users.active.alphabetically.includes(:identity)
  end

  def update
    @account.update!(account_params)
    redirect_to account_settings_path
  end

  private
    def set_account
      @account = Current.account
    end

    def account_params
      params.expect account: %i[name]
    end
end
```

### Account::CancellationsController

Allows account owners to cancel/delete their account.

```ruby
# app/controllers/account/cancellations_controller.rb
class Account::CancellationsController < ApplicationController
  before_action :ensure_owner

  def new
  end

  def create
    Current.account.cancel
    redirect_to session_menu_path(script_name: nil), notice: "Account deleted"
  end

  private
    def ensure_owner
      head :forbidden unless Current.user.owner?
    end
end
```

### Account::ExportsController

Full account data export for admins/owners (GDPR compliance, data portability).

```ruby
# app/controllers/account/exports_controller.rb
class Account::ExportsController < ApplicationController
  before_action :ensure_admin_or_owner
  before_action :ensure_export_limit_not_exceeded, only: :create
  before_action :set_export, only: :show

  CURRENT_EXPORT_LIMIT = 10

  def show
  end

  def create
    Current.account.exports.create!(user: Current.user).build_later
    redirect_to account_settings_path, notice: "Export started. You'll receive an email when it's ready."
  end

  private
    def ensure_admin_or_owner
      head :forbidden unless Current.user.admin? || Current.user.owner?
    end

    def ensure_export_limit_not_exceeded
      head :too_many_requests if Current.account.exports.current.count >= CURRENT_EXPORT_LIMIT
    end

    def set_export
      @export = Current.account.exports.completed.find_by(id: params[:id], user: Current.user)
    end
end
```

### Account::ImportsController

Import data from exported ZIP files to create or restore accounts.

```ruby
# app/controllers/account/imports_controller.rb
class Account::ImportsController < ApplicationController
  layout "public"

  disallow_account_scope only: %i[new create]
  allow_unauthorized_access only: :show
  before_action :set_import, only: :show
  before_action :ensure_accessed_by_owner, only: :show

  def new
  end

  def create
    signup = Signup.new(identity: Current.identity, full_name: "Import", skip_account_seeding: true)

    if signup.complete
      start_import(signup.account)
    else
      render :new, alert: "Couldn't create account."
    end
  end

  def show
  end

  private
    def set_import
      @import = Current.account.imports.find(params[:id])
    end

    def ensure_accessed_by_owner
      head :forbidden unless @import.identity == Current.identity
    end

    def start_import(account)
      import = nil

      Current.set(account: account) do
        import = account.imports.create!(identity: Current.identity, file: params[:file])
        import.process_later
      end

      redirect_to account_import_path(import, script_name: account.slug)
    end
end
```

### Account::JoinCodesController

Manages invitation codes for team members to join the account.

```ruby
# app/controllers/account/join_codes_controller.rb
class Account::JoinCodesController < ApplicationController
  before_action :set_join_code
  before_action :ensure_admin, only: %i[update destroy]

  def show
  end

  def edit
  end

  def update
    if @join_code.update(join_code_params)
      redirect_to account_join_code_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @join_code.reset
    redirect_to account_join_code_path, notice: "Join code has been reset"
  end

  private
    def set_join_code
      @join_code = Current.account.join_code
    end

    def join_code_params
      params.expect account_join_code: [:usage_limit]
    end
end
```

### JoinsController (Public Join Flow)

Handles the public join flow when users redeem a join code.

```ruby
# app/controllers/joins_controller.rb
class JoinsController < ApplicationController
  disallow_account_scope
  allow_unauthenticated_access only: :show
  require_unauthenticated_access only: :show

  layout "public"

  rate_limit to: 10, within: 1.minute, only: :create

  def show
    @join_code = Account::JoinCode.active.find_by!(code: params[:code])
    @account = @join_code.account
  end

  def create
    join_code = Account::JoinCode.find_by!(code: params[:code])

    # Check if user already has access to this account
    if Current.identity.users.exists?(account: join_code.account)
      redirect_to root_path(script_name: join_code.account.slug), notice: "You're already a member of this account"
      return
    end

    # Check if join code is still active (not at limit)
    unless join_code.active?
      redirect_to join_path(code: params[:code]), alert: "This invite link has reached its usage limit"
      return
    end

    joined = join_code.redeem_if do
      join_account(join_code.account)
    end

    if joined
      redirect_to new_users_verification_path(script_name: join_code.account.slug)
    else
      redirect_to join_path(code: params[:code]), alert: "This invite link is no longer valid"
    end
  end

  private
    def join_account(account)
      return false if Current.identity.users.exists?(account: account)

      account.users.create!(
        identity: Current.identity,
        name: Current.identity.email_address,
        role: :member
      )
      true
    end
end
```

---

## Middleware

### Account Slug Extractor

```ruby
# config/initializers/tenanting/account_slug.rb
module AccountSlug
  class Extractor
    ACCOUNT_PATTERN = %r{\A/(\d{7,})}  # 7+ digit account IDs

    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)

      if (match = request.path_info.match(ACCOUNT_PATTERN))
        account_id = match[1]

        if (account = Account.find_by(external_account_id: account_id))
          # Move account slug from PATH_INFO to SCRIPT_NAME
          env["SCRIPT_NAME"] = "#{env['SCRIPT_NAME']}/#{account_id}"
          env["PATH_INFO"] = request.path_info.sub("/#{account_id}", "")
          env["PATH_INFO"] = "/" if env["PATH_INFO"].empty?

          Current.account = account
        end
      else
        Current.account = nil
      end

      @app.call(env)
    ensure
      Current.reset
    end
  end
end

Rails.application.config.middleware.insert_after Rack::TempfileReaper, AccountSlug::Extractor
```

### True Client IP (for Cloudflare/Load Balancers)

```ruby
# config/initializers/true_client_ip.rb
class TrueClientIp
  def initialize(app)
    @app = app
  end

  def call(env)
    if (true_ip = env["HTTP_TRUE_CLIENT_IP"])
      env["HTTP_X_FORWARDED_FOR"] = true_ip
    end
    @app.call(env)
  end
end

Rails.application.config.middleware.insert_before ActionDispatch::RemoteIp, TrueClientIp
```

---

## Views & UI Flow

### Session Views

```erb
<%# app/views/sessions/new.html.erb %>
<div class="auth-container">
  <h1>Get into Your App</h1>

  <%= form_with url: session_path, method: :post do |f| %>
    <%= f.email_field :email_address,
        placeholder: "Enter your email address...",
        autocomplete: "email",
        autofocus: true,
        required: true %>
    <%= f.submit "Let's go" %>
  <% end %>

  <% if Account.accepting_signups? %>
    <p>New here? We'll create an account for you.</p>
  <% end %>
</div>
```

```erb
<%# app/views/sessions/magic_links/show.html.erb %>
<div class="auth-container">
  <h1>Check your email</h1>
  <p>Enter the verification code sent to <%= @email_address %></p>

  <%= form_with url: session_magic_link_path, method: :post do |f| %>
    <%= f.text_field :code,
        maxlength: 6,
        autocomplete: "one-time-code",
        autofocus: true,
        placeholder: "••••••",
        style: "text-transform: uppercase; text-align: center" %>
    <%= f.submit "Verify" %>
  <% end %>

  <p class="hint">This code will work for 15 minutes.</p>

  <% if Rails.env.development? && flash[:magic_link_code] %>
    <p class="dev-code">Dev code: <%= flash[:magic_link_code] %></p>
  <% end %>
</div>
```

### Signup Views

```erb
<%# app/views/signups/new.html.erb %>
<div class="auth-container">
  <h1>Sign up</h1>

  <%= form_with url: signup_path, method: :post do |f| %>
    <%= f.email_field :email_address,
        placeholder: "Enter your email address...",
        autocomplete: "email",
        autofocus: true,
        required: true %>
    <%= f.submit "Let's go" %>
  <% end %>
</div>
```

```erb
<%# app/views/signups/completions/new.html.erb %>
<div class="auth-container">
  <h1>Complete your sign-up</h1>
  <p>Just enter your name to create your account.</p>

  <%= form_with url: signup_completion_path, method: :post do |f| %>
    <%= f.text_field :full_name,
        placeholder: "Enter your full name...",
        autocomplete: "name",
        autofocus: true,
        required: true %>
    <%= f.submit "Continue" %>
  <% end %>
</div>
```

### Onboarding Views (Initial Setup)

These views are shown during the first-boot onboarding process when no accounts exist yet.

```erb
<%# app/views/onboardings/new.html.erb %>
<div class="auth-container">
  <h1>Welcome! Let's set up your organization</h1>
  <p>Enter your email address to get started.</p>

  <%= form_with url: onboarding_path, method: :post do |f| %>
    <%= f.email_field :email_address,
        placeholder: "Enter your email address...",
        autocomplete: "email",
        autofocus: true,
        required: true %>
    <%= f.submit "Continue" %>
  <% end %>
</div>
```

```erb
<%# app/views/onboardings/completions/new.html.erb %>
<div class="auth-container">
  <h1>Complete your setup</h1>
  <p>Enter your details to create your organization.</p>

  <%= form_with url: onboarding_completion_path, method: :post do |f| %>
    <div class="field">
      <%= f.label :organization_name, "Organization name" %>
      <%= f.text_field :organization_name,
          placeholder: "Acme Inc.",
          autocomplete: "organization",
          autofocus: true,
          required: true %>
    </div>

    <div class="field">
      <%= f.label :full_name, "Your name" %>
      <%= f.text_field :full_name,
          placeholder: "Enter your full name...",
          autocomplete: "name",
          required: true %>
    </div>

    <%= f.submit "Create organization" %>
  <% end %>
</div>
```

### User Management Views

```erb
<%# app/views/users/verifications/new.html.erb %>
<div class="auth-container">
  <h1>Verify your email</h1>
  <p>Click below to verify your email address and join the account.</p>

  <%= form_with url: users_verification_path, method: :post do |f| %>
    <%= f.submit "Verify my email" %>
  <% end %>
</div>
```

```erb
<%# app/views/users/joins/new.html.erb %>
<div class="auth-container">
  <h1>Complete your profile</h1>
  <p>Enter your name to finish joining the account.</p>

  <%= form_with model: Current.user, url: users_join_path, method: :post do |f| %>
    <%= f.text_field :name,
        placeholder: "Enter your name...",
        autocomplete: "name",
        autofocus: true,
        required: true %>

    <div class="avatar-upload">
      <%= f.label :avatar, "Profile photo (optional)" %>
      <%= f.file_field :avatar, accept: "image/jpeg,image/png,image/gif,image/webp" %>
    </div>

    <%= f.submit "Continue" %>
  <% end %>
</div>
```

```erb
<%# app/views/users/email_addresses/new.html.erb %>
<div class="settings-container">
  <h1>Change your email</h1>
  <p>Enter your new email address, then check your email to confirm the change.</p>

  <%= form_with url: user_email_address_path(@user), method: :post do |f| %>
    <%= f.email_field :email_address,
        placeholder: "New email address",
        autocomplete: "email",
        autofocus: true,
        required: true %>
    <%= f.submit "Continue" %>
  <% end %>

  <%= link_to "Back to profile", @user %>
</div>
```

```erb
<%# app/views/users/email_addresses/confirmations/show.html.erb %>
<div class="auth-container">
  <h1>Confirm email change</h1>
  <p>Click below to confirm your new email address.</p>

  <%= form_with url: user_email_address_confirmation_path(@user), method: :post do |f| %>
    <%= f.hidden_field :email_address_token, value: params[:email_address_token] %>
    <%= f.submit "Confirm email change" %>
  <% end %>
</div>
```

```erb
<%# app/views/users/email_addresses/confirmations/invalid_token.html.erb %>
<div class="auth-container">
  <h1>Invalid or expired link</h1>
  <p>This email change link is no longer valid. Please request a new one.</p>
  <%= link_to "Back to profile", root_path %>
</div>
```

```erb
<%# app/views/users/data_exports/show.html.erb %>
<div class="settings-container">
  <h1>Your data export</h1>

  <% if @export %>
    <p>Your export is ready for download.</p>
    <%= link_to "Download export", rails_blob_path(@export.file, disposition: "attachment"), class: "button" %>
    <p class="hint">This download will be available for 24 hours.</p>
  <% else %>
    <p>Export not found or still processing.</p>
  <% end %>

  <%= link_to "Back to profile", @user %>
</div>
```

### Account Management Views

```erb
<%# app/views/account/settings/show.html.erb %>
<div class="settings-container">
  <h1>Account Settings</h1>

  <section class="settings-section">
    <h2>Account Name</h2>
    <% if Current.user.admin? %>
      <%= form_with model: @account, url: account_settings_path, method: :patch do |f| %>
        <%= f.text_field :name, required: true %>
        <%= f.submit "Save" %>
      <% end %>
    <% else %>
      <p><%= @account.name %></p>
    <% end %>
  </section>

  <section class="settings-section">
    <h2>Team Members (<%= @users.count %>)</h2>
    <ul class="user-list">
      <% @users.each do |user| %>
        <li>
          <%= image_tag user_avatar_path(user), class: "avatar" %>
          <span class="name"><%= user.name %></span>
          <span class="email"><%= user.identity&.email_address %></span>
          <span class="role"><%= user.role.titleize %></span>
        </li>
      <% end %>
    </ul>
  </section>

  <% if Current.user.admin? %>
    <section class="settings-section">
      <h2>Invite Team Members</h2>
      <%= link_to "Manage invite link", account_join_code_path, class: "button" %>
    </section>

    <section class="settings-section">
      <h2>Export Account Data</h2>
      <%= button_to "Start Export", account_exports_path, method: :post, class: "button" %>
    </section>
  <% end %>

  <% if Current.user.owner? %>
    <section class="settings-section danger">
      <h2>Delete Account</h2>
      <p>Permanently delete this account and all its data.</p>
      <%= link_to "Delete account...", new_account_cancellation_path, class: "button danger" %>
    </section>
  <% end %>
</div>
```

```erb
<%# app/views/account/cancellations/new.html.erb %>
<div class="settings-container">
  <h1>Delete Account</h1>

  <div class="warning-box">
    <h2>Are you sure?</h2>
    <p>This will permanently delete the account "<strong><%= Current.account.name %></strong>" and all its data.</p>
    <p>This action cannot be undone. Your data will be retained for 30 days before permanent deletion.</p>
  </div>

  <%= form_with url: account_cancellation_path, method: :post do |f| %>
    <p>
      <%= f.submit "Yes, delete this account", class: "button danger" %>
      <%= link_to "Cancel", account_settings_path, class: "button" %>
    </p>
  <% end %>
</div>
```

```erb
<%# app/views/account/join_codes/show.html.erb %>
<div class="settings-container">
  <h1>Invite Link</h1>

  <p>Share this link with people you want to invite to your account:</p>

  <div class="invite-link-box">
    <code><%= @join_code.join_url %></code>
    <button onclick="navigator.clipboard.writeText('<%= @join_code.join_url %>')">Copy</button>
  </div>

  <p class="hint">
    This link has been used <%= @join_code.usage_count %> times.
    <% if @join_code.usage_limit < Account::JoinCode::USAGE_LIMIT_MAX %>
      Limit: <%= @join_code.usage_limit %> uses.
    <% end %>
  </p>

  <% if Current.user.admin? %>
    <p>
      <%= link_to "Edit usage limit", edit_account_join_code_path, class: "button" %>
      <%= button_to "Reset link", account_join_code_path, method: :delete, class: "button",
          data: { confirm: "This will invalidate the current invite link. Continue?" } %>
    </p>
  <% end %>

  <%= link_to "Back to settings", account_settings_path %>
</div>
```

```erb
<%# app/views/account/join_codes/edit.html.erb %>
<div class="settings-container">
  <h1>Edit Invite Link</h1>

  <%= form_with model: @join_code, url: account_join_code_path, method: :patch do |f| %>
    <div class="field">
      <%= f.label :usage_limit, "Maximum uses" %>
      <%= f.number_field :usage_limit, min: @join_code.usage_count + 1, max: Account::JoinCode::USAGE_LIMIT_MAX %>
      <p class="hint">Set the maximum number of times this invite link can be used.</p>
    </div>

    <p>
      <%= f.submit "Save" %>
      <%= link_to "Cancel", account_join_code_path %>
    </p>
  <% end %>
</div>
```

```erb
<%# app/views/account/exports/show.html.erb %>
<div class="settings-container">
  <h1>Account Export</h1>

  <% if @export %>
    <p>Your export is ready for download.</p>
    <%= link_to "Download export", rails_blob_path(@export.file, disposition: "attachment"), class: "button" %>
    <p class="hint">This download will be available for 24 hours.</p>
  <% else %>
    <p>Export not found or still processing.</p>
  <% end %>

  <%= link_to "Back to settings", account_settings_path %>
</div>
```

```erb
<%# app/views/account/imports/new.html.erb %>
<div class="auth-container">
  <h1>Import Account</h1>
  <p>Upload an exported account file to create a new account with your data.</p>

  <%= form_with url: account_imports_path, method: :post, multipart: true do |f| %>
    <div class="field">
      <%= f.label :file, "Export file (ZIP)" %>
      <%= f.file_field :file, accept: ".zip", required: true %>
    </div>

    <%= f.submit "Import" %>
  <% end %>

  <%= link_to "Or sign up for a new account", new_signup_path %>
</div>
```

```erb
<%# app/views/account/imports/show.html.erb %>
<div class="settings-container">
  <h1>Import Status</h1>

  <% case @import.status %>
  <% when "pending", "processing" %>
    <p>Your import is being processed. This page will refresh automatically.</p>
    <div class="spinner"></div>
    <meta http-equiv="refresh" content="5">
  <% when "completed" %>
    <p>Your import has completed successfully!</p>
    <%= link_to "Go to your account", root_path, class: "button" %>
  <% when "failed" %>
    <p>Your import failed. Please try again or contact support.</p>
    <%= link_to "Try again", new_account_import_path(script_name: nil), class: "button" %>
  <% end %>
</div>
```

```erb
<%# app/views/joins/show.html.erb %>
<div class="auth-container">
  <h1>Join <%= @account.name %></h1>
  <p>You've been invited to join this account.</p>

  <%= form_with url: join_path(code: @join_code.code), method: :post do |f| %>
    <%= f.submit "Join account" %>
  <% end %>

  <p class="hint">Already have an account? <%= link_to "Sign in", new_session_path %></p>
</div>
```

---

## Mailers

### Magic Link Mailer

```ruby
# app/mailers/magic_link_mailer.rb
class MagicLinkMailer < ApplicationMailer
  def sign_in_instructions(identity, magic_link)
    @identity = identity
    @magic_link = magic_link
    @purpose = magic_link.purpose

    mail(
      to: identity.email_address,
      subject: "Your verification code is #{magic_link.code}"
    )
  end
end
```

```erb
<%# app/views/magic_link_mailer/sign_in_instructions.html.erb %>
<h1><%= @purpose == "sign_up" ? "Welcome!" : "Your verification code" %></h1>

<p>
  Enter this code on the
  <%= @purpose == "sign_up" ? "sign-up" : "sign-in" %> page:
</p>

<p style="font-size: 32px; font-family: monospace; letter-spacing: 4px;">
  <%= @magic_link.code %>
</p>

<p>This code will work for 15 minutes.</p>
```

```text
<%# app/views/magic_link_mailer/sign_in_instructions.text.erb %>
<%= @purpose == "sign_up" ? "Welcome!" : "Your verification code" %>

Enter this code on the <%= @purpose == "sign_up" ? "sign-up" : "sign-in" %> page:

<%= @magic_link.code %>

This code will work for 15 minutes.
```

### User Mailer

```ruby
# app/mailers/user_mailer.rb
class UserMailer < ApplicationMailer
  def email_change_confirmation(user, new_email_address, token)
    @user = user
    @new_email_address = new_email_address
    @confirmation_url = user_email_address_confirmation_url(
      user,
      email_address_token: token,
      script_name: user.account.slug
    )

    mail(
      to: new_email_address,
      subject: "Confirm your new email address"
    )
  end
end
```

```erb
<%# app/views/user_mailer/email_change_confirmation.html.erb %>
<h1>Confirm your email address change</h1>

<p>Click the button below to confirm your new email address:</p>

<p>
  <%= link_to "Yes, use this email address", @confirmation_url, style: "display: inline-block; padding: 12px 24px; background: #007bff; color: white; text-decoration: none; border-radius: 4px;" %>
</p>

<p>This link will expire in 30 minutes.</p>

<p>
  <em>If you didn't request this change, you can ignore this email.
  Your email address will NOT be changed unless you click the button above.</em>
</p>
```

```text
<%# app/views/user_mailer/email_change_confirmation.text.erb %>
Confirm your email address change

Click the link below to confirm your new email address:

<%= @confirmation_url %>

This link will expire in 30 minutes.

If you didn't request this change, you can ignore this email.
Your email address will NOT be changed unless you click the link above.
```

### Export Mailer

```ruby
# app/mailers/export_mailer.rb
class ExportMailer < ApplicationMailer
  def completed(export)
    @export = export
    @user = export.user
    @download_url = user_data_export_url(
      @user,
      export,
      script_name: @user.account.slug
    )

    mail(
      to: @user.identity.email_address,
      subject: "Your data export is ready"
    )
  end
end
```

```erb
<%# app/views/export_mailer/completed.html.erb %>
<h1>Your data export is ready</h1>

<p>Your requested data export has been generated and is ready for download.</p>

<p>
  <%= link_to "Download your export", @download_url, style: "display: inline-block; padding: 12px 24px; background: #007bff; color: white; text-decoration: none; border-radius: 4px;" %>
</p>

<p><em>This download will be available for 24 hours.</em></p>
```

```text
<%# app/views/export_mailer/completed.text.erb %>
Your data export is ready

Your requested data export has been generated and is ready for download.

Download your export: <%= @download_url %>

This download will be available for 24 hours.
```

### Account Mailer

```ruby
# app/mailers/account_mailer.rb
class AccountMailer < ApplicationMailer
  def cancelled(account, initiated_by)
    @account = account
    @initiated_by = initiated_by
    @incineration_date = account.incineration_scheduled_for

    mail(
      to: initiated_by.identity.email_address,
      subject: "Your account has been deleted"
    )
  end

  def import_completed(import)
    @import = import
    @account = import.account
    @dashboard_url = root_url(script_name: @account.slug)

    mail(
      to: import.identity.email_address,
      subject: "Your account import is complete"
    )
  end

  def import_failed(import, error_message = nil)
    @import = import
    @account = import.account
    @error_message = error_message

    mail(
      to: import.identity.email_address,
      subject: "Your account import failed"
    )
  end
end
```

```erb
<%# app/views/account_mailer/cancelled.html.erb %>
<h1>Account Deleted</h1>

<p>The account "<strong><%= @account.name %></strong>" has been deleted.</p>

<p>Your data will be retained until <strong><%= @incineration_date.strftime("%B %d, %Y") %></strong>,
after which it will be permanently deleted.</p>

<p>If you change your mind, please contact support before that date to restore your account.</p>
```

```text
<%# app/views/account_mailer/cancelled.text.erb %>
Account Deleted

The account "<%= @account.name %>" has been deleted.

Your data will be retained until <%= @incineration_date.strftime("%B %d, %Y") %>,
after which it will be permanently deleted.

If you change your mind, please contact support before that date to restore your account.
```

```erb
<%# app/views/account_mailer/import_completed.html.erb %>
<h1>Import Complete</h1>

<p>Your account import has completed successfully!</p>

<p>
  <%= link_to "Go to your account", @dashboard_url, style: "display: inline-block; padding: 12px 24px; background: #007bff; color: white; text-decoration: none; border-radius: 4px;" %>
</p>
```

```text
<%# app/views/account_mailer/import_completed.text.erb %>
Import Complete

Your account import has completed successfully!

Go to your account: <%= @dashboard_url %>
```

```erb
<%# app/views/account_mailer/import_failed.html.erb %>
<h1>Import Failed</h1>

<p>Unfortunately, your account import could not be completed.</p>

<% if @error_message %>
  <p>Error: <%= @error_message %></p>
<% end %>

<p>Please try again or contact support if the problem persists.</p>
```

```text
<%# app/views/account_mailer/import_failed.text.erb %>
Import Failed

Unfortunately, your account import could not be completed.

<% if @error_message %>
Error: <%= @error_message %>
<% end %>

Please try again or contact support if the problem persists.
```

---

## Security Measures

### 1. Content Security Policy

```ruby
# config/initializers/content_security_policy.rb
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.script_src  :self, :strict_dynamic
    policy.style_src   :self, :unsafe_inline
    policy.img_src     :self, :data, :blob
    policy.font_src    :self, :data
    policy.object_src  :none
    policy.base_uri    :none
    policy.frame_ancestors :self
    policy.form_action :self
  end

  config.content_security_policy_nonce_generator = ->(request) {
    SecureRandom.base64(16)
  }
  config.content_security_policy_nonce_directives = %w[script-src]
end
```

### 2. SSRF Protection

```ruby
# app/models/ssrf_protection.rb
module SsrfProtection
  PRIVATE_RANGES = [
    IPAddr.new("0.0.0.0/8"),
    IPAddr.new("10.0.0.0/8"),
    IPAddr.new("100.64.0.0/10"),
    IPAddr.new("127.0.0.0/8"),
    IPAddr.new("169.254.0.0/16"),
    IPAddr.new("172.16.0.0/12"),
    IPAddr.new("192.168.0.0/16"),
    IPAddr.new("198.18.0.0/15"),
    IPAddr.new("::1/128"),
    IPAddr.new("fc00::/7"),
    IPAddr.new("fe80::/10")
  ].freeze

  DNS_SERVERS = ["1.1.1.1", "8.8.8.8"].freeze
  DNS_TIMEOUT = 2

  def self.resolve_public_ip(hostname)
    resolver = Resolv::DNS.new(nameserver: DNS_SERVERS)
    resolver.timeouts = DNS_TIMEOUT

    addresses = resolver.getaddresses(hostname)
    public_address = addresses.find { |addr| public_ip?(addr.to_s) }

    raise "No public IP found for #{hostname}" unless public_address
    public_address.to_s
  ensure
    resolver&.close
  end

  def self.public_ip?(ip_string)
    ip = IPAddr.new(ip_string)
    PRIVATE_RANGES.none? { |range| range.include?(ip) }
  rescue IPAddr::InvalidAddressError
    false
  end
end
```

### 3. Parameter Filtering

```ruby
# config/initializers/filter_parameter_logging.rb
Rails.application.config.filter_parameters += [
  :passw, :secret, :token, :_key, :crypt, :salt,
  :certificate, :otp, :ssn, :code
]
```

### 4. SSL Configuration (Production)

```ruby
# config/environments/production.rb
Rails.application.configure do
  config.force_ssl = ENV.fetch("FORCE_SSL", "true") == "true"
  config.assume_ssl = true
end
```

### 5. Rate Limiting

Built into controllers using Rails 7.1+ `rate_limit` method:

```ruby
class SessionsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create
end

class Sessions::MagicLinksController < ApplicationController
  rate_limit to: 10, within: 15.minutes, only: :create
end

class JoinsController < ApplicationController
  rate_limit to: 10, within: 1.minute, only: :create  # Rate limit join code redemption
end
```

---

## Background Jobs

### SessionCleanupJob

Removes expired sessions from the database. Should run daily.

```ruby
# app/jobs/session_cleanup_job.rb
class SessionCleanupJob < ApplicationJob
  queue_as :maintenance

  def perform
    deleted_count = Session.expired.delete_all
    Rails.logger.info "[SessionCleanupJob] Deleted #{deleted_count} expired sessions"
  end
end
```

### MagicLinkCleanupJob

Removes expired magic links from the database. Should run daily.

```ruby
# app/jobs/magic_link_cleanup_job.rb
class MagicLinkCleanupJob < ApplicationJob
  queue_as :maintenance

  def perform
    deleted_count = MagicLink.cleanup
    Rails.logger.info "[MagicLinkCleanupJob] Deleted #{deleted_count} expired magic links"
  end
end
```

### ExportCleanupJob

Removes stale exports (completed exports older than 24 hours, failed exports older than 7 days).

```ruby
# app/jobs/export_cleanup_job.rb
class ExportCleanupJob < ApplicationJob
  queue_as :maintenance

  def perform
    deleted_count = Export.cleanup
    Rails.logger.info "[ExportCleanupJob] Deleted #{deleted_count} stale exports"
  end
end
```

### AccessTokenCleanupJob

Removes expired access tokens that have been expired for more than 30 days.

```ruby
# app/jobs/access_token_cleanup_job.rb
class AccessTokenCleanupJob < ApplicationJob
  queue_as :maintenance

  RETENTION_PERIOD = 30.days

  def perform
    deleted_count = Identity::AccessToken
      .where("expires_at IS NOT NULL AND expires_at < ?", RETENTION_PERIOD.ago)
      .delete_all
    Rails.logger.info "[AccessTokenCleanupJob] Deleted #{deleted_count} expired tokens"
  end
end
```

### Recurring Jobs Configuration

```yaml
# config/recurring.yml
production:
  session_cleanup:
    class: SessionCleanupJob
    schedule: every day at 3am

  magic_link_cleanup:
    class: MagicLinkCleanupJob
    schedule: every day at 3:15am

  export_cleanup:
    class: ExportCleanupJob
    schedule: every day at 3:30am

  access_token_cleanup:
    class: AccessTokenCleanupJob
    schedule: every day at 3:45am
```

---

## Audit Logging

### AuditLog Model

For tracking security-sensitive administrative actions. Provides an audit trail for compliance and security review.

```ruby
# db/migrate/xxx_create_audit_logs.rb
create_table :audit_logs, id: :string do |t|
  t.references :account, null: false, foreign_key: true, type: :string
  t.references :user, null: false, foreign_key: true, type: :string
  t.string :action, null: false  # "user.role_changed", "user.deactivated", etc.
  t.references :target, polymorphic: true, type: :string
  t.json :details  # Action-specific data
  t.string :ip_address
  t.string :user_agent
  t.timestamps
end
add_index :audit_logs, :action
add_index :audit_logs, :created_at
```

```ruby
# app/models/audit_log.rb
class AuditLog < ApplicationRecord
  belongs_to :account
  belongs_to :user
  belongs_to :target, polymorphic: true, optional: true

  validates :action, presence: true

  # Standard action names
  ACTIONS = {
    user_role_changed: "user.role_changed",
    user_deactivated: "user.deactivated",
    user_reactivated: "user.reactivated",
    user_email_changed: "user.email_changed",
    account_cancelled: "account.cancelled",
    account_reactivated: "account.reactivated",
    join_code_reset: "join_code.reset",
    access_token_created: "access_token.created",
    access_token_revoked: "access_token.revoked",
    session_revoked: "session.revoked",
    all_sessions_revoked: "session.all_revoked"
  }.freeze

  def self.record(action, target: nil, details: {})
    return unless Current.account && Current.user

    create!(
      account: Current.account,
      user: Current.user,
      action: action,
      target: target,
      details: details,
      ip_address: Current.request&.remote_ip,
      user_agent: Current.request&.user_agent
    )
  end
end
```

### Usage Example

```ruby
# In Users::RolesController
def update
  old_role = @user.role
  @user.update!(role_params)

  AuditLog.record(
    AuditLog::ACTIONS[:user_role_changed],
    target: @user,
    details: { old_role: old_role, new_role: @user.role }
  )

  redirect_to account_settings_path
end
```

---

## Implementation Checklist

### Phase 1: Core Models
- [ ] Create Identity model with email validation and normalization
- [ ] Create Session model with identity association, expiration, and integrity validation
- [ ] Create MagicLink model with code generation and expiration
- [ ] Create Account model with external_account_id generation
- [ ] Create User model with Role concern
- [ ] Create Current context model
- [ ] Create AuditLog model for admin action tracking
- [ ] Run migrations

### Phase 2: Authentication
- [ ] Implement Authentication concern (including onboarding redirect)
- [ ] Implement Authentication::ViaMagicLink concern
- [ ] Add session expiration validation (expires_at field + TTL)
- [ ] Add session integrity validation (IP/user_agent consistency check)
- [ ] Add session activity refresh on each request
- [ ] Fix bearer token auth to set Current.user based on account context
- [ ] Create SessionsController (new, create, destroy)
- [ ] Create Sessions::MagicLinksController (show, create) - handle sign_in, sign_up, and onboarding purposes
- [ ] Create SignupsController (new, create)
- [ ] Create Signups::CompletionsController (new, create)
- [ ] Create Signup form object with account name capping and duplicate prevention

### Phase 3: Initial Onboarding (First-Boot Setup)
- [ ] Add `requires_onboarding?` method to Account::MultiTenantable concern
- [ ] Add `:onboarding` purpose to MagicLink model
- [ ] Create Onboarding form object (collects org name, sets staff flag)
- [ ] Add race condition guard with database advisory lock to Onboarding
- [ ] Create OnboardingsController (new, create)
- [ ] Create Onboardings::CompletionsController (new, create)
- [ ] Create onboarding views (email entry, completion with org name)
- [ ] Add onboarding routes to config/routes.rb
- [ ] Add multi_tenant configuration initializer (MULTI_TENANT env var)
- [ ] Verify first-boot redirect triggers when Account.none?
- [ ] Verify onboarding creates Identity with staff=true
- [ ] Verify onboarding creates User with role=owner
- [ ] Document system user purpose (automated actions, imports, scheduled jobs)

### Phase 4: Authorization
- [ ] Implement Authorization concern
- [ ] Implement Authorization::ResourceAccess concern for granular permissions
- [ ] Implement RequestForgeryProtection concern
- [ ] Add role-based checks to User model
- [ ] Create Access model (if using resource-level permissions)
- [ ] Wire Access model to controllers via authorize_access_to helper

### Phase 5: User Management
- [ ] Create User::EmailAddressChangeable concern
- [ ] Create User::Avatar concern with image validation
- [ ] Create User::Configurable concern
- [ ] Create User::Settings model
- [ ] Create Push::Subscription model with SSRF protection
- [ ] Create Export base model with STI
- [ ] Create User::DataExport model
- [ ] Add session termination on user deactivation
- [ ] Create Users::RolesController with audit logging
- [ ] Create Users::VerificationsController
- [ ] Create Users::JoinsController
- [ ] Create Users::EmailAddressesController with cross-account validation
- [ ] Create Users::EmailAddresses::ConfirmationsController
- [ ] Create Users::DataExportsController
- [ ] Create Users::PushSubscriptionsController
- [ ] Create Users::AvatarsController

### Phase 6: Token & Session Management
- [ ] Add expires_at, last_used_at, last_used_ip, revoked_at to access_tokens table
- [ ] Update AccessToken model with expiration and revocation support
- [ ] Add token usage tracking (record_usage! method)
- [ ] Create Identity::AccessTokensController (index, new, create, destroy)
- [ ] Create Identity::SessionsController (index, destroy, destroy_all)
- [ ] Create token management views (list, new, one-time token display)
- [ ] Create session management views (list, revoke)
- [ ] Add "revoke all sessions" feature
- [ ] Add routes for identity-scoped token/session management

### Phase 7: Account Management
- [ ] Create Account::Cancellable concern with callbacks
- [ ] Create Account::Incineratable concern (30-day grace period)
- [ ] Create Account::MultiTenantable concern
- [ ] Create Account::Cancellation model
- [ ] Create Account::JoinCode model with redemption logic
- [ ] Create Account::Export model
- [ ] Create Account::Import model
- [ ] Create Account::SettingsController
- [ ] Create Account::CancellationsController (owner only)
- [ ] Create Account::ExportsController (admin/owner)
- [ ] Create Account::ImportsController
- [ ] Create Account::JoinCodesController
- [ ] Create JoinsController (public join flow with rate limiting and limit error handling)

### Phase 8: Middleware
- [ ] Implement AccountSlug::Extractor middleware
- [ ] Configure middleware ordering
- [ ] Implement TrueClientIp middleware (if behind proxy)

### Phase 9: Views & Mailers
- [ ] Create session views (new, magic_link/show)
- [ ] Create signup views (new, completions/new)
- [ ] Create onboarding views (new, completions/new)
- [ ] Create user management views (verification, join, email change)
- [ ] Create account management views (settings, cancellation, join codes, exports)
- [ ] Create join flow views (public join page)
- [ ] Create token management views (list, create, one-time display)
- [ ] Create session management views (list, revoke)
- [ ] Create MagicLinkMailer with text/HTML templates (handle onboarding purpose)
- [ ] Create UserMailer for email change confirmations
- [ ] Create ExportMailer for export notifications
- [ ] Create AccountMailer for cancellation and import notifications
- [ ] Create public layout for auth pages

### Phase 10: Security
- [ ] Configure Content Security Policy
- [ ] Configure parameter filtering
- [ ] Configure SSL in production
- [ ] Add rate limiting to auth controllers
- [ ] Add rate limiting to email change controllers
- [ ] Add rate limiting to join code redemption
- [ ] Implement SSRF protection for push subscriptions
- [ ] Implement SSRF protection for outbound requests

### Phase 11: Background Jobs
- [ ] Create DataExportJob for async user data export
- [ ] Create Account::DataExportJob for async account export
- [ ] Create Account::DataImportJob for async account import
- [ ] Create AccountIncinerationJob for delayed account deletion (30-day grace)
- [ ] Create PushNotificationJob for push delivery
- [ ] Create SessionCleanupJob (daily cleanup of expired sessions)
- [ ] Create MagicLinkCleanupJob (daily cleanup of expired magic links)
- [ ] Create ExportCleanupJob (remove exports older than 24 hours)
- [ ] Create AccessTokenCleanupJob (remove expired tokens older than 30 days)
- [ ] Create import cleanup job (remove failed imports older than 7 days)
- [ ] Configure recurring.yml for scheduled cleanup jobs

### Phase 12: Audit Logging
- [ ] Create AuditLog model with action tracking
- [ ] Add audit logging to role changes (Users::RolesController)
- [ ] Add audit logging to user deactivation
- [ ] Add audit logging to account cancellation
- [ ] Add audit logging to join code reset
- [ ] Add audit logging to token creation/revocation
- [ ] Add audit logging to session revocation

### Phase 13: Testing
- [ ] Write model tests for all auth models
- [ ] Write model tests for user management models
- [ ] Write model tests for account management models
- [ ] Write model tests for Onboarding form object
- [ ] Write controller tests for auth flows
- [ ] Write controller tests for user management flows
- [ ] Write controller tests for account management flows
- [ ] Write controller tests for onboarding flows
- [ ] Write controller tests for token management flows
- [ ] Write controller tests for session management flows
- [ ] Write integration tests for complete auth journey
- [ ] Write integration tests for initial onboarding flow (first-boot)
- [ ] Write integration tests for email change flow
- [ ] Write integration tests for join code redemption flow
- [ ] Write integration tests for account export/import flow
- [ ] Write integration tests for account cancellation flow
- [ ] Test session expiration after 2 weeks of inactivity
- [ ] Test session integrity validation with IP change
- [ ] Test bearer token auth populates Current.user correctly
- [ ] Test token expiration and revocation
- [ ] Test cleanup jobs remove stale data
- [ ] Test rate limiting behavior
- [ ] Test multi-tenant isolation
- [ ] Test SSRF protection
- [ ] Test first-boot redirect when Account.none?
- [ ] Test onboarding race condition prevention
- [ ] Test onboarding creates staff identity and owner user
- [ ] Test user deactivation terminates all sessions
- [ ] Test audit log records admin actions

---

## Routes Configuration

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Public auth routes (no account scope)
  resource :session, only: [:new, :create, :destroy] do
    resource :magic_link, only: [:show, :create], controller: "sessions/magic_links"
    resource :menu, only: :show, controller: "sessions/menus"
  end

  resource :signup, only: [:new, :create] do
    resource :completion, only: [:new, :create], controller: "signups/completions"
  end

  # Initial onboarding (first-boot, no account scope)
  resource :onboarding, only: [:new, :create] do
    resource :completion, only: [:new, :create], controller: "onboardings/completions"
  end

  # Public join flow (no account scope)
  resources :joins, only: [:show, :create], param: :code

  # Account import (creates new account, no account scope)
  namespace :account do
    resources :imports, only: [:new, :create]
  end

  # Identity-scoped routes (token & session management, no account scope)
  namespace :identity do
    resources :access_tokens, only: [:index, :new, :create, :destroy]
    resources :sessions, only: [:index, :destroy] do
      collection do
        delete :destroy_all
      end
    end
  end

  # Account-scoped routes
  scope "/:account_id" do
    root "dashboards#show"

    # Account management routes
    namespace :account do
      resource :settings, only: [:show, :update]
      resource :cancellation, only: [:new, :create]
      resource :join_code, only: [:show, :edit, :update, :destroy]
      resources :exports, only: [:show, :create]
      resources :imports, only: [:show]
    end

    # User management routes
    namespace :users do
      resource :verification, only: [:new, :create]
      resource :join, only: [:new, :create]
    end

    resources :users, only: [:show, :edit, :update] do
      resource :role, only: :update, controller: "users/roles"
      resource :avatar, only: [:show, :destroy], controller: "users/avatars"
      resource :email_address, only: [:new, :create], controller: "users/email_addresses" do
        resource :confirmation, only: [:show, :create], controller: "users/email_addresses/confirmations"
      end
      resources :data_exports, only: [:show, :create], controller: "users/data_exports"
      resources :push_subscriptions, only: [:index, :create, :destroy], controller: "users/push_subscriptions"
    end

    # Your application routes here...
  end
end
```

---

## Key Design Decisions

1. **Passwordless over passwords**: Eliminates password storage risks, simplifies UX
2. **6-character codes over links**: More mobile-friendly, works across email clients
3. **Identity/User separation**: Enables single identity across multiple organizations
4. **URL-based tenancy**: Simpler than subdomains, works easily in development
5. **Signed cookies**: Tamper-proof session tokens without server-side session storage
6. **Rate limiting at controller level**: Simple, declarative, built into Rails
7. **SSRF protection**: Essential for any webhook or outbound request functionality
8. **Secure string comparison**: Prevents timing attacks on code verification
9. **First-boot onboarding flow**: When no accounts exist, users are automatically redirected to `/onboarding` to set up the initial organization. The first user gets both `staff: true` on their Identity (global privilege) and `role: :owner` on their User (account-level ownership), ensuring they have full administrative access
10. **Session expiration with activity refresh**: Sessions expire after 2 weeks of inactivity but are automatically extended on each request, providing security without disrupting active users
11. **Soft token revocation**: Access tokens support soft revocation (revoked_at timestamp) for audit trails while allowing immediate invalidation
12. **Advisory locks for race conditions**: Critical operations like first-boot onboarding use database advisory locks to prevent race conditions without blocking reads
13. **System user for automated actions**: Each account has a system user for attributing automated actions (imports, scheduled jobs) without associating them with a human user

---

## Known Limitations and Edge Cases

This section documents known limitations and edge cases that implementations should be aware of.

### Session Management

1. **Session termination on user deactivation is account-global**: When a user is deactivated, ALL sessions for their identity are terminated across ALL accounts. Consider adding account-scoped session tracking if users frequently switch between accounts.

2. **IP change detection policy is global**: The `IP_CHANGE_POLICY` setting applies to all sessions. Consider making this configurable per-user or per-account if needed.

3. **No device fingerprinting**: Session integrity relies on IP and user_agent only. Sophisticated attackers with access to both could potentially hijack sessions.

### Token Management

1. **Tokens are identity-scoped, not account-scoped**: An access token grants access to ALL accounts the identity has access to. For multi-tenant deployments where users need account-specific API access, consider adding account-scoped tokens.

2. **Binary permissions only**: Tokens have read or write permission at the HTTP method level. There's no resource-level scoping (e.g., "read only from board X"). Consider extending permissions if needed.

3. **No per-token rate limiting**: Rate limits are controller-global, not per-token. High-volume API users share rate limits.

### Multi-Tenancy

1. **Cross-account validation relies on Current context**: Controllers must always verify `Current.user` belongs to `Current.account`. The authentication concern sets this up correctly for cookie-based auth, but API implementations should verify.

2. **Staff flag is global**: The `staff: true` flag on Identity is not account-scoped. Staff users have elevated privileges across all accounts.

### Onboarding

1. **First-boot race condition uses PostgreSQL advisory locks**: If using a different database, replace `pg_advisory_xact_lock` with an appropriate locking mechanism.

2. **System user is created automatically**: The system user exists for automated actions but has no login capability. Don't delete it or automated processes will fail.

### Email Changes

1. **Email change doesn't invalidate sessions**: After changing email, existing sessions remain valid. Consider terminating sessions on email change for security-sensitive applications.

2. **Email change confirmation is time-limited**: The confirmation token expires in 30 minutes. If the user doesn't confirm in time, they need to request a new change.

### Join Codes

1. **Join code redemption is rate-limited**: 10 attempts per minute per IP. This may be too aggressive for shared corporate networks.

2. **Usage limit error handling**: When a join code reaches its limit, users see a generic error. Consider providing more context or prompting them to contact an admin.

---

## Security Considerations

### Recommended Security Headers

Beyond CSP, consider adding these headers:

```ruby
# config/initializers/security_headers.rb
Rails.application.config.action_dispatch.default_headers.merge!(
  'X-Content-Type-Options' => 'nosniff',
  'X-Frame-Options' => 'SAMEORIGIN',
  'X-XSS-Protection' => '1; mode=block',
  'Referrer-Policy' => 'strict-origin-when-cross-origin',
  'Permissions-Policy' => 'geolocation=(), microphone=(), camera=()'
)
```

### Recommended Monitoring

Consider implementing alerts for:

- Multiple failed magic link attempts from same IP
- Session creation from new IP/device for existing users
- Token creation/revocation spikes
- User role escalations (member → admin)
- Account cancellation requests
- Unusual API activity patterns

### Incident Response

If a session or token is compromised:

1. **For sessions**: User can revoke via Identity::SessionsController or use "revoke all" feature
2. **For tokens**: Admin/user can revoke via Identity::AccessTokensController
3. **For identity compromise**: Deactivate all users associated with the identity across all accounts

### Compliance Notes

This specification supports:

- **GDPR Article 17** (Right to Erasure): Account cancellation with 30-day grace period, user data exports
- **GDPR Article 20** (Data Portability): Account export/import functionality
- **Session management best practices**: Expiration, integrity validation, user-controlled revocation
