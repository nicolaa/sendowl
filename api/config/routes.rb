Rails.application.routes.draw do
  # Test-only seam: the Playwright e2e suite reads the most recently delivered email
  # (the download link) through this endpoint. Guarded to the test env so it never
  # exists in development or production.
  if Rails.env.test?
    get "test/latest_email", to: "test_mail#latest"
  end

  namespace :api do
    namespace :v1 do
      resources :products, only: [:index, :show]
      resources :orders, only: [:create, :index] do
        post :resend_link, on: :member
      end
      resources :downloads, only: [:show], param: :token do
        post :trigger, on: :member
      end
    end
  end
end
