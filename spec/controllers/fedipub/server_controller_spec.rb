require 'rails_helper'

RSpec.describe Fedipub::ServerController, type: :controller do
  controller do
    define_method(:create) do
      skip_authorization
      head :ok
    end
  end

  [:post, :put, :patch, :delete].each do |method|
    it "rejects a badly-signed optional #{method.upcase} request" do
      routes.draw { match 'write' => 'fedipub/server#create', via: method }
      request.headers['Signature'] = 'poop'

      public_send(method, :create)

      expect(response).to have_http_status :unauthorized
    end
  end
end
