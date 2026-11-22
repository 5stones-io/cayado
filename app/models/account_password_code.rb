# An emailed 6-digit code that sets or resets an account's password.
# One live code per account: issuing a new one replaces the old. Only a
# digest is stored, keyed to the account so a code can't be tried against
# anyone else's. Used by the :password_code Rodauth feature
# (lib/rodauth/features/password_code.rb).
class AccountPasswordCode < ApplicationRecord
  LIFETIME        = 15.minutes
  SIGNUP_LIFETIME = 72.hours
  MAX_ATTEMPTS    = 5
  # A second request inside this window keeps the code already sent rather
  # than emailing another one.
  RESEND_AFTER = 1.minute

  self.primary_key = :id

  belongs_to :account, foreign_key: :id

  # Returns the new code, or nil if one was sent too recently.
  def self.issue!(account, lifetime: LIFETIME)
    existing = find_by(id: account.id)
    return nil if existing && existing.created_at > RESEND_AFTER.ago && existing.deadline > Time.current

    code = format("%06d", SecureRandom.random_number(1_000_000))
    upsert(
      { id: account.id, code_digest: digest(account, code), deadline: lifetime.from_now, attempts: 0, created_at: Time.current },
      unique_by: :id
    )
    code
  end

  # True for a live, matching code. Every wrong try counts toward
  # MAX_ATTEMPTS, after which the code is dead and a new one is needed.
  def self.valid_for?(account, code)
    record = find_by(id: account.id)
    return false unless record && record.deadline > Time.current && record.attempts < MAX_ATTEMPTS

    normalized = code.to_s.gsub(/\D/, "")
    if normalized.length == 6 && ActiveSupport::SecurityUtils.secure_compare(record.code_digest, digest(account, normalized))
      true
    else
      record.increment!(:attempts)
      false
    end
  end

  def self.consume!(account)
    where(id: account.id).delete_all
  end

  def self.digest(account, code)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.key_generator.generate_key("account password codes"), "#{account.id}:#{code}")
  end
  private_class_method :digest
end
