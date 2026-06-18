class Order < ApplicationRecord
  attr_accessor :raw_token_for_mailer

  belongs_to :product
  has_one :download_link, dependent: :destroy

  validates :buyer_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  after_create :generate_download_link

  def reset_download_link!
    # Atomic: destroy + recreate must both succeed or neither does, otherwise a failure
    # mid-way would leave the order with no link. with_lock also serializes concurrent
    # resends (and resend-vs-download races) on this order's row.
    with_lock do
      old_count = download_link&.download_count || 0
      download_link&.destroy!
      generate_download_link(old_count)
    end
  end

  private

  def generate_download_link(starting_count = 0)
    self.raw_token_for_mailer = SecureRandom.urlsafe_base64(32)
    hashed_token = Digest::SHA256.hexdigest(raw_token_for_mailer)
    base_time = self.created_at || Time.current
    expires_at = base_time + product.expiry_hours.hours
    create_download_link!(
      token_hash: hashed_token,
      expires_at: expires_at,
      download_count: starting_count
    )
  end
end
