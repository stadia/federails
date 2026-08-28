# rbs_inline: enabled

module Fedipub
  module Server
    class NodeinfoController < Fedipub::ServerController
      def index
        skip_authorization

        render_serialized(
          Fedipub::Server::NodeinfoIndexResource,
          Fedipub::Server::NodeinfoIndexPayload.new(href: show_node_info_url),
          content_type: Mime[:nodeinfo]
        )
      end

      def show # rubocop:todo Metrics/AbcSize
        skip_authorization

        @total = @active_halfyear = @active_month = 0
        @has_user_counts = false
        Fedipub::Configuration.actor_types.each_value do |config|
          next unless (method = config[:user_count_method]&.to_sym)

          @has_user_counts = true
          model = config[:class]
          @total += model.send(method, nil)
          @active_month += model.send(method, (30.days.ago)...Time.current)
          @active_halfyear += model.send(method, (180.days.ago)...Time.current)
        end
        render_serialized(
          Fedipub::Server::NodeinfoResource,
          Fedipub::Server::NodeinfoPayload.new(
            software_name:      Fedipub::Configuration.app_name&.parameterize,
            software_version:   Fedipub::Configuration.app_version,
            open_registrations: Fedipub::Configuration.open_registrations,
            has_user_counts:    @has_user_counts,
            total:              @total,
            active_month:       @active_month,
            active_halfyear:    @active_halfyear,
            metadata:           Fedipub::Configuration.nodeinfo_metadata || {}
          ),
          content_type: Mime[:nodeinfo]
        )
      end
    end
  end
end
