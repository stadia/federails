require 'rails_helper'

module Federails
  RSpec.describe Configuration do
    describe '#base_client_controller=' do
      it 'changes the base controller' do
        # Dummy application has the base_client_controller overridden; it's easier to test it directly, as reloading the controller
        # _class_ in the test after changing the configuration option seems complicated.
        expect(Federails::ClientController.superclass).to be ::ApplicationController
      end
    end
  end
end
