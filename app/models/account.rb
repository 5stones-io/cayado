class Account < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :churches, through: :memberships

  before_validation :normalize_email

  # nil until they've given a name (an invite not yet accepted); callers
  # fall back to the email.
  def name
    [first_name, last_name].compact_blank.join(" ").presence
  end

  private

  # Saved emails are always lowercase, and every sign-in lookup downcases
  # too, so two spellings of one email can't become two accounts.
  def normalize_email
    self.email = email.to_s.strip.downcase if email.present?
  end
end
