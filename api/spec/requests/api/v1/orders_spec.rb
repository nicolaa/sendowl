require 'rails_helper'

RSpec.describe "Api::V1::Orders", type: :request do
  let!(:product) { Product.create!(name: 'Test', file_placeholder: 'url', expiry_hours: 24, max_download_count: 2) }

  describe "GET /api/v1/orders" do
    let!(:older_order) { Order.create!(product: product, buyer_email: 'older@example.com') }
    let!(:newer_order) { Order.create!(product: product, buyer_email: 'newer@example.com') }

    it "returns orders newest-first with product and download_link embedded" do
      get '/api/v1/orders'

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      # Scope to this spec's own orders so the assertion holds regardless of any other
      # rows already in the database (the dashboard relies on this newest-first ordering).
      ours = json.map { |o| o['buyer_email'] }.select { |e| %w[newer@example.com older@example.com].include?(e) }
      expect(ours).to eq([ 'newer@example.com', 'older@example.com' ])

      newest = json.find { |o| o['buyer_email'] == 'newer@example.com' }
      expect(newest['product']['name']).to eq('Test')
      expect(newest['download_link']).to be_present
      expect(newest['download_link']['expires_at']).to be_present
    end

    it "never exposes the token_hash in the serialized download_link" do
      get '/api/v1/orders'

      json = JSON.parse(response.body)
      mine = json.find { |o| o['buyer_email'] == 'newer@example.com' }
      expect(mine['download_link']).not_to have_key('token_hash')
    end
  end

  describe "POST /api/v1/orders" do
    it "creates an order and generates a download link" do
      post '/api/v1/orders', params: { order: { product_id: product.id, buyer_email: 'buyer@example.com' } }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['buyer_email']).to eq('buyer@example.com')
    end

    it "rejects an invalid email and does not create an order" do
      expect {
        post '/api/v1/orders', params: { order: { product_id: product.id, buyer_email: 'not-an-email' } }
      }.not_to change(Order, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors']).to be_present
    end
  end

  describe "POST /api/v1/orders/:id/resend_link" do
    let!(:order) { Order.create!(product: product, buyer_email: 'buyer@example.com') }

    it "resets the download link and sends a new one" do
      old_token_hash = order.download_link.token_hash

      post "/api/v1/orders/#{order.id}/resend_link"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      order.reload
      expect(order.download_link.token_hash).not_to eq(old_token_hash)
    end

    it "preserves the download count and original expiry window on resend" do
      original_expires_at = order.download_link.expires_at
      order.download_link.update!(download_count: 1)

      post "/api/v1/orders/#{order.id}/resend_link"

      expect(response).to have_http_status(:ok)
      order.reload
      # A new token is issued, but the clock and the already-consumed downloads carry over:
      # resend re-delivers a still-valid link, it never refreshes or refunds it.
      expect(order.download_link.download_count).to eq(1)
      expect(order.download_link.expires_at).to be_within(1.second).of(original_expires_at)
    end

    it "returns an error if the link is expired" do
      order.download_link.update!(expires_at: 1.day.ago)

      post "/api/v1/orders/#{order.id}/resend_link"

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['error']).to eq('Link is expired')
    end

    it "returns an error if the download limit is reached" do
      order.download_link.update!(download_count: 2)

      post "/api/v1/orders/#{order.id}/resend_link"

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['error']).to eq('Download limit reached')
    end
  end
end
