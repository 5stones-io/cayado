# Who must use two-step sign-in: everyone. Every Cayado account is church
# staff (or a platform admin), and a church's plans aren't something a
# leaked password should open. Kept as one place to ask, as in
# spirely-cloud, in case that ever changes.
module TwoStepPolicy
  def self.required?(account_id)
    account_id.present?
  end
end
