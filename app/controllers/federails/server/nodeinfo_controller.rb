module Federails
  module Server
    class NodeinfoController < ServerController
      def index
        render formats: [:nodeinfo]
      end

      def show # rubocop:todo Metrics/AbcSize
        @total = @active_halfyear = @active_month = 0
        Federails::Configuration.entity_types.each_value do |config|
          next unless config[:include_in_user_count]

          model = config[:class]
          @total += model.count
          @active_month += model.where(created_at: ((30.days.ago)...Time.current)).count
          @active_halfyear += model.where(created_at: ((180.days.ago)...Time.current)).count
        end
        render formats: [:nodeinfo]
      end
    end
  end
end
