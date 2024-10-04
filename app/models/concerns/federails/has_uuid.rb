module Federails
  module HasUuid
    extend ActiveSupport::Concern

    included do
      before_validation :generate_uuid
      validates :uuid, presence: true, uniqueness: true

      def self.find_param(param)
        find_by!(uuid: param)
      end
    end

    def to_param
      uuid
    end

    # Override UUID accessor to provide lazy initialization of UUIDs for old data
    def uuid
      generate_uuid and save! if self[:uuid].blank?
      self[:uuid]
    end

    private

    def generate_uuid
      return if self[:uuid].present?

      (self.uuid = SecureRandom.uuid) while self[:uuid].blank? || self.class.exists?(uuid: self[:uuid])
    end
  end
end
