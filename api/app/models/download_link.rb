class DownloadLink < ApplicationRecord
  attr_accessor :raw_token

  belongs_to :order

  validates :token_hash, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :download_count, numericality: { greater_than_or_equal_to: 0 }

  def expired?
    Time.current > expires_at
  end

  def limit_reached?
    download_count >= order.product.max_download_count
  end

  def active?
    !expired? && !limit_reached?
  end

  def increment_download!
    # Pessimistic locking to prevent concurrent downloads from exceeding limit
    with_lock do
      if active?
        update!(download_count: download_count + 1)
        true
      else
        false
      end
    end
  end

  # Security-by-default: token_hash must never reach the API surface. Excluding it
  # here (rather than in each controller) means it stays hidden across every
  # serialization path -- including future endpoints and `include:` associations --
  # without anyone having to remember an `except:` list. The raw token is unrecoverable
  # from the hash, but it is an internal value the frontend has no reason to see.
  def serializable_hash(options = nil)
    super(options).except("token_hash")
  end
end
