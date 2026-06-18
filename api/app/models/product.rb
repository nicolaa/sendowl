class Product < ApplicationRecord
  has_many :orders, dependent: :destroy

  validates :name, presence: true
  validates :file_placeholder, presence: true
  validates :expiry_hours, numericality: { greater_than: 0 }
  validates :max_download_count, numericality: { greater_than: 0 }
end
