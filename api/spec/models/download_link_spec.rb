require 'rails_helper'

RSpec.describe DownloadLink, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  let(:product) { Product.create!(name: 'Test', file_placeholder: 'url', expiry_hours: 24, max_download_count: 2) }
  let(:order) { Order.create!(product: product, buyer_email: 'test@example.com') }

  it 'is active initially' do
    link = order.download_link
    expect(link.active?).to be true
  end

  it 'expires after expiry_hours' do
    link = order.download_link
    travel 25.hours do
      expect(link.active?).to be false
      expect(link.expired?).to be true
    end
  end

  it 'becomes inactive when download count is reached' do
    link = order.download_link
    link.update!(download_count: 2)
    expect(link.active?).to be false
    expect(link.limit_reached?).to be true
  end

  it 'safely increments download count concurrently without exceeding limit' do
    link = order.download_link

    threads = []
    5.times do
      threads << Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          DownloadLink.find(link.id).increment_download!
        end
      end
    end

    threads.each(&:join)

    expect(link.reload.download_count).to eq(2)
  end
end
