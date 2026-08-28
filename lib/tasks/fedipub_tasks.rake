namespace :fedipub do
  desc 'Re-fetches every remote actors to update database'
  task sync_actors: :environment do
    Fedipub::Maintenance::ActorsUpdater.run do |actor, status|
      puts "#{actor.federated_url}: #{status}"
    end
  end

  desc 'Re-fetches every host and completes missing ones'
  task sync_hosts: :environment do
    Fedipub::Maintenance::HostsUpdater.run
  end
end
