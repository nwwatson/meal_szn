Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # =============================================================================
  # Public Authentication Routes (no account scope)
  # =============================================================================

  # Session management (sign in/out)
  resource :session, only: %i[new create destroy] do
    resource :magic_link, only: %i[show create], controller: "sessions/magic_links"
  end

  # New account signup flow
  resource :signup, only: %i[new create] do
    resource :completion, only: %i[new create], controller: "signups/completions"
  end

  # First-boot onboarding flow (creates first account)
  resource :onboarding, only: %i[new create] do
    resource :completion, only: %i[new create], controller: "onboardings/completions"
  end

  # =============================================================================
  # Identity-scoped routes (manage your global identity settings)
  # =============================================================================

  namespace :identity do
    resources :access_tokens, only: %i[index new create destroy]
    resources :sessions, only: %i[index destroy]
  end

  # =============================================================================
  # Account-scoped routes (accessed via /:account_id prefix)
  # The AccountSlug::Extractor middleware extracts the account from the URL
  # =============================================================================

  scope module: :accounts do
    # Dashboard
    root "dashboards#show", as: :account_root

    # Recipes (web UI)
    resources :recipes do
      member do
        get :resolve_ingredients
        patch :apply_resolution
      end
      collection do
        get :search_usda
        get :import_url
        post :start_import
        get :import_photo
        post :start_photo_import
        get :import_status
        get :import_review
      end
    end

    # Dietary Profiles
    resources :dietary_profiles, except: :show

    # Meal Plans (web UI)
    resources :meal_plans do
      member do
        post :duplicate
      end
      resource :shopping_list, only: %i[show create destroy], controller: "shopping_lists"
      resources :meals, only: %i[create destroy], controller: "meal_plan_meals"
      resources :participants, only: %i[create destroy], controller: "meal_plan_participants"
      resources :portions, only: :update, controller: "meal_plan_meal_portions"
    end

    resources :shopping_list_items, only: :destroy do
      member do
        patch :toggle
      end
    end

    # User settings
    resource :settings, only: %i[show update]

    # =============================================================================
    # API v1 Routes
    # =============================================================================
    namespace :api do
      namespace :v1 do
        # RecipeScanner iOS API
        resources :recipes, only: %i[index show create update destroy]

        # Claude Meal Planning API
        namespace :meal_planning do
          resources :recipes, only: %i[index show]
        end

        resources :meal_plans, only: %i[index show create update destroy]
      end
    end
  end
end
