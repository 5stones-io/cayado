class CustomDomain < ApplicationRecord
  belongs_to :church

  validates :hostname, presence: true, uniqueness: true

  before_validation :normalize_hostname
  before_validation :generate_verification_token, on: :create

  def verified?
    verified_at.present?
  end

  def verify!
    update!(verified_at: Time.current)
  end

  private

  def normalize_hostname
    self.hostname = hostname.to_s.strip.downcase if hostname.present?
  end

  def generate_verification_token
    self.verification_token ||= SecureRandom.hex(16)
  end
end
