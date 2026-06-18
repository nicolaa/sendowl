require 'rails_helper'

RSpec.describe "Api::V1::Products", type: :request do
  let!(:ebook) { Product.create!(name: 'E-Book', file_placeholder: 'https://example.com/ebook.pdf', expiry_hours: 24, max_download_count: 3) }
  let!(:source) { Product.create!(name: 'Source Code', file_placeholder: 'https://example.com/source.zip', expiry_hours: 48, max_download_count: 5) }

  describe "GET /api/v1/products" do
    it "returns the created products" do
      get '/api/v1/products'

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      # Assert our products are present rather than an exact total, so the spec is robust
      # against any rows already in the database.
      expect(json.map { |p| p['name'] }).to include('E-Book', 'Source Code')
    end
  end

  describe "GET /api/v1/products/:id" do
    it "returns a single product with its download settings" do
      get "/api/v1/products/#{ebook.id}"

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['name']).to eq('E-Book')
      expect(json['expiry_hours']).to eq(24)
      expect(json['max_download_count']).to eq(3)
    end

    it "returns 404 for a non-existent product" do
      get "/api/v1/products/0"

      expect(response).to have_http_status(:not_found)
    end
  end
end
