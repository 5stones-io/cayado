module Cayado
  module Api
    module V1
      # Notify team (Sermons screen, admin): a heads-up about a series to
      # every ministry lead. GET previews the dialog; POST sends it by email
      # and puts it in each lead's Activity ("push": in the app; real push
      # notifications come with cayado_mobile).
      class NotifyController < BaseController
        include Cayado::PlanningJson

        CHANNELS = %w[email push].freeze

        before_action :require_admin!
        before_action :set_series

        def show
          render json: { recipients: recipients.map { person_json(_1) }, channels: CHANNELS,
                         subject: subject, body: default_body }
        end

        def create
          channels = Array(params[:channels]).map(&:to_s)
          if channels.empty? || (channels - CHANNELS).any?
            return render json: { error: "Channels must be some of #{CHANNELS.join(', ')}", code: "invalid_channels" },
                          status: :unprocessable_content
          end
          if recipients.empty?
            return render json: { error: "No ministry has a lead to notify", code: "no_recipients" },
                          status: :unprocessable_content
          end

          body = params[:body].presence || default_body
          ActivityEvent.create!(church: Current.church, actor_membership: Current.membership, kind: "team_notified",
                                sermon_series: @series,
                                data: { subject: subject, excerpt: ActivityEvent.excerpt(body), channels: channels,
                                        recipient_ids: recipients.map(&:id) })
          email_recipients(body) if channels.include?("email")

          render json: { notified: recipients.size }, status: :created
        end

        private

        def set_series
          @series = Current.church.sermon_series.find(params[:sermon_series_id])
        end

        # Every ministry lead but the sender, once each, by name.
        def recipients
          @recipients ||= ministries.filter_map(&:lead_membership).uniq
                                    .reject { _1.id == Current.membership.id }
                                    .sort_by { _1.account.name || _1.account.email }
        end

        def subject = "Heads up — #{@series.title} is on the calendar."

        def default_body
          "Plans, alignment slots, and conversations are open in Cayado. " \
            "Take a look this week and add your piece. — #{Current.account.name || Current.account.email}"
        end

        def email_recipients(body)
          link = "https://#{Current.church.primary_hostname}/sermons?series=#{@series.id}"
          recipients.each do |membership|
            TeamEmail.heads_up(to: membership.account.email, church_name: Current.church.brand_name,
                               subject: subject, body: body, link: link)
          end
        end
      end
    end
  end
end
