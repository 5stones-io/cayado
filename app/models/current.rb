class Current < ActiveSupport::CurrentAttributes
  # custom_domain: the verified CustomDomain this request arrived on, if any.
  attribute :church, :account, :membership, :custom_domain
end
