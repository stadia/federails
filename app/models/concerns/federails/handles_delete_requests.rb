module Federails
  # Model concern providing hooks for on_federails_delete_requested callback
  #
  # ```rb
  # # Example migration
  # add_column :my_table, :uuid, :text, default: nil, index: { unique: true }
  # ```
  #
  # Usage:
  #
  # ```rb
  # class MyModel < ApplicationRecord
  #   include Federails::HandlesDeleteRequests
  #
  #   on_federails_delete_requested -> { delete! }
  # end
  module HandlesDeleteRequests
    extend ActiveSupport::Concern

    # Class methods automatically included in the concern.
    module ClassMethods
      def on_federails_delete_requested(*args)
        set_callback :on_federails_delete_requested, *args
      end

      def on_federails_undelete_requested(*args)
        set_callback :on_federails_undelete_requested, *args
      end
    end

    included do
      define_callbacks :on_federails_delete_requested
      define_callbacks :on_federails_undelete_requested
    end
  end
end
