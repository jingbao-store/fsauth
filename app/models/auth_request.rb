class AuthRequest < ApplicationRecord
  belongs_to :application

  validates :request_id, presence: true, uniqueness: true
  validates :state, inclusion: { in: %w[pending authorized expired failed] }
  validates :expires_at, presence: true

  # Check if the request has expired
  def expired?
    expires_at && Time.current > expires_at
  end

  # Check if the request is valid (pending and not expired)
  def valid_request?
    state == 'pending' && !expired?
  end

  # Mark request as expired
  def mark_as_expired!
    update!(state: 'expired')
  end

  # Mark request as authorized
  def mark_as_authorized!
    update!(state: 'authorized')
  end

  # Mark request as failed
  def mark_as_failed!
    update!(state: 'failed')
  end
end
