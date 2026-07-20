require 'rails_helper'

RSpec.describe 'Federails::CopyClientViews', type: :generator do
  it 'copies all the client views' do # rubocop:disable RSpec/ExampleLength
    output = `bundle exec rails generate federails:copy_client_views --pretend --skip`
             .split("\n")
             .map(&:strip)
             .join("\n")

    expect(output).to eq <<~TXT.strip
      create  spec/dummy/app/views/federails/client
      create  spec/dummy/app/views/federails/client/activities/_activity.html.erb
      create  spec/dummy/app/views/federails/client/activities/_activity.json.jbuilder
      create  spec/dummy/app/views/federails/client/activities/_index.json.jbuilder
      create  spec/dummy/app/views/federails/client/activities/feed.html.erb
      create  spec/dummy/app/views/federails/client/activities/feed.json.jbuilder
      create  spec/dummy/app/views/federails/client/activities/index.html.erb
      create  spec/dummy/app/views/federails/client/activities/index.json.jbuilder
      create  spec/dummy/app/views/federails/client/actors/_actor.json.jbuilder
      create  spec/dummy/app/views/federails/client/actors/_lookup_form.html.erb
      create  spec/dummy/app/views/federails/client/actors/gone.html.erb
      create  spec/dummy/app/views/federails/client/actors/index.html.erb
      create  spec/dummy/app/views/federails/client/actors/index.json.jbuilder
      create  spec/dummy/app/views/federails/client/actors/show.html.erb
      create  spec/dummy/app/views/federails/client/actors/show.json.jbuilder
      create  spec/dummy/app/views/federails/client/common/_client_links.html.erb
      create  spec/dummy/app/views/federails/client/followings/_follow.html.erb
      create  spec/dummy/app/views/federails/client/followings/_follow_actions.html.erb
      create  spec/dummy/app/views/federails/client/followings/_follower.html.erb
      create  spec/dummy/app/views/federails/client/followings/_following.json.jbuilder
      create  spec/dummy/app/views/federails/client/followings/_form.html.erb
      create  spec/dummy/app/views/federails/client/followings/index.html.erb
      create  spec/dummy/app/views/federails/client/followings/index.json.jbuilder
      create  spec/dummy/app/views/federails/client/followings/show.html.erb
      create  spec/dummy/app/views/federails/client/followings/show.json.jbuilder
    TXT
  end
end
