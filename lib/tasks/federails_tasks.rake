namespace :federails do
  desc 'Re-fetches every remote actors to update database'
  task sync_actors: :environment do
    Federails::Maintenance::ActorUpdater.run do |actor, status|
      puts "#{actor.federated_url}: #{status}"
    end
  end
end
