require 'rails_helper'

RSpec.describe "Api::V1::Downloads", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let!(:product) { Product.create!(name: 'Test', file_placeholder: 'https://example.com/file', expiry_hours: 24, max_download_count: 2) }
  let!(:order) { Order.create!(product: product, buyer_email: 'buyer@example.com') }
  let!(:link) { order.download_link }

  describe "GET /api/v1/downloads/:token" do
    it "does not increment download count" do
      get "/api/v1/downloads/#{order.raw_token_for_mailer}"

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['product_name']).to eq('Test')
      expect(json['remaining_downloads']).to eq(2)
      expect(json['expires_at']).to be_present
      expect(json['expired']).to be(false)
      expect(json['limit_reached']).to be(false)
      expect(link.reload.download_count).to eq(0)
    end

    # show returns 200 (not a 4xx) for dead links on purpose, so the buyer page can
    # render a specific explanation. These lock that contract in.
    it "returns 200 with expired flag for an expired link" do
      travel 25.hours do
        get "/api/v1/downloads/#{order.raw_token_for_mailer}"

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['expired']).to be(true)
        expect(json['limit_reached']).to be(false)
        expect(json['expires_at']).to be_present
      end
    end

    it "returns 200 with limit_reached flag and clamps remaining_downloads to zero" do
      link.update!(download_count: 2)

      get "/api/v1/downloads/#{order.raw_token_for_mailer}"

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['limit_reached']).to be(true)
      expect(json['expired']).to be(false)
      expect(json['remaining_downloads']).to eq(0)
    end

    it "returns 404 for an unknown token" do
      get "/api/v1/downloads/this-token-does-not-exist"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/downloads/:token/trigger" do
    it "increments download count and returns file_url JSON" do
      post "/api/v1/downloads/#{order.raw_token_for_mailer}/trigger"

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['file_url']).to eq('https://example.com/file')
      expect(link.reload.download_count).to eq(1)
    end

    it "returns forbidden when limit is reached" do
      link.update!(download_count: 2)
      post "/api/v1/downloads/#{order.raw_token_for_mailer}/trigger"

      expect(response).to have_http_status(:forbidden)
      expect(response.body).to eq('Download limit reached')
    end

    it "returns forbidden when expired" do
      travel 25.hours do
        post "/api/v1/downloads/#{order.raw_token_for_mailer}/trigger"

        expect(response).to have_http_status(:forbidden)
        expect(response.body).to eq('Download link expired')
      end
    end
  end
end
