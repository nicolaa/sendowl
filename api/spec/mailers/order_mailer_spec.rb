require "rails_helper"

RSpec.describe OrderMailer, type: :mailer do
  describe "download_link" do
    let(:product) { Product.create!(name: 'E-Book', file_placeholder: 'url', expiry_hours: 24, max_download_count: 2) }
    let(:order) { Order.create!(product: product, buyer_email: 'buyer@example.com') }
    let(:raw_token) { 'my-super-secret-token' }
    let(:mail) { OrderMailer.download_link(order, raw_token) }

    it "renders the headers" do
      expect(mail.subject).to eq("Your download link for E-Book")
      expect(mail.to).to eq([ "buyer@example.com" ])
      expect(mail.from).to eq([ "no-reply@sendowl-clone.com" ])
    end

    it "renders the body with the correct download URL" do
      expect(mail.body.encoded).to include("http://localhost:5173/download/my-super-secret-token")
    end
  end
end
