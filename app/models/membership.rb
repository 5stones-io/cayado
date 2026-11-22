# Everyone with a membership is church staff: Cayado is for the pastor and
# their team. Admins and owners also change the church's settings, vision
# and other people's work; members fill in their own.
class Membership < ApplicationRecord
  ROLES = %w[member admin owner].freeze

  belongs_to :account
  belongs_to :church

  validates :role, inclusion: { in: ROLES }
  validates :account_id, uniqueness: { scope: :church_id }

  def admin_or_owner?
    role.in?(%w[admin owner])
  end
end
