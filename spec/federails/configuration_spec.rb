require 'rails_helper'

module Federails
  RSpec.describe Configuration do
    describe '#logger' do
      let(:original_logger) { described_class.logger }

      after do
        described_class.logger = original_logger
      end

      it 'provides a standard logger by default' do
        described_class.logger = nil

        aggregate_failures do
          expect(described_class.logger).to be_a Logger
          expect(described_class.logger.progname).to eq 'federails'
        end
      end

      it 'allows injecting a custom logger' do
        custom_logger = Logger.new($stdout)
        described_class.logger = custom_logger

        expect(described_class.logger).to be custom_logger
      end
    end

    describe '#base_client_controller=' do
      it 'changes the base controller' do
        # Dummy application has the base_client_controller overridden; it's easier to test it directly, as reloading the controller
        # _class_ in the test after changing the configuration option seems complicated.
        expect(Federails::ClientController.superclass).to be ::ApplicationController
      end
    end
  end
end
