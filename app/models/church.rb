class Church < ApplicationRecord
  STATUSES = %w[pending approved suspended].freeze
  DEFAULT_TIMEZONE = "America/Chicago".freeze

  has_many :memberships, dependent: :destroy
  has_many :accounts, through: :memberships
  has_many :custom_domains, dependent: :destroy

  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9]([a-z0-9\-]*[a-z0-9])?\z/, message: "must be lowercase letters, numbers, and hyphens" }
  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :timezone, inclusion: { in: ActiveSupport::TimeZone.all.map { |z| z.tzinfo.name } }, allow_nil: true

  def brand_name
    display_name.presence || name
  end

  def time_zone
    ActiveSupport::TimeZone[timezone.presence || DEFAULT_TIMEZONE]
  end

  # Today where the church is, which is what "this week" means.
  def today
    Time.current.in_time_zone(time_zone).to_date
  end

  def suspended?
    status == "suspended"
  end

  # A verified primary custom domain, else default_hostname.
  def primary_hostname
    custom_domains.find { |d| d.primary? && d.verified? }&.hostname || default_hostname
  end

  # One fixed host for a self-hosted install; cayado-cloud overrides this
  # with {slug}.cayado.cloud.
  def default_hostname
    ENV.fetch("APP_HOST", "localhost:3000")
  end
end
