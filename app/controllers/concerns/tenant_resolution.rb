module TenantResolution
  extend ActiveSupport::Concern

  included do
    before_action :resolve_tenant!
  end

  private

  # Which church a request is for, from the Host header: a verified custom
  # domain, then the {slug} subdomain, then (for a self-hosted install with
  # one church) that church. In the controller, not a route constraint,
  # since custom domains can't be pattern-matched in routes.
  def resolve_tenant!
    Current.custom_domain = CustomDomain.where.not(verified_at: nil).find_by(hostname: request.host.to_s.downcase)
    Current.church =
      Current.custom_domain&.church ||
      Church.find_by(slug: request.subdomain) ||
      sole_church_fallback
  end

  # Only with exactly one church. With two or more, guessing would show one
  # church's plans to another's staff.
  def sole_church_fallback
    Church.sole
  rescue ActiveRecord::RecordNotFound, ActiveRecord::SoleRecordExceeded
    nil
  end

  def require_tenant!
    return if Current.church

    # Not `respond_to`: ActionController::API doesn't include MimeResponds.
    # The API always answers JSON, whatever the request asked for.
    if is_a?(ActionController::API) || request.format.json?
      render json: { error: "Not found", code: "not_found" }, status: :not_found
    else
      head :not_found
    end
  end
end
