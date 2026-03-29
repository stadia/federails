namespace :federails do
  namespace :delivery do
    desc 'Retry all dead letter deliveries'
    task retry_dead_letters: :environment do
      Federails::DeadLetter.find_each do |dl|
        Federails::NotifyInboxJob.perform_later(dl.activity)
        dl.destroy!
      end
    end

    desc 'Clean up dead letters older than N days (default: 30)'
    task :cleanup, [:days] => :environment do |_t, args|
      days = (args[:days] || 30).to_i
      count = Federails::DeadLetter.where('created_at < ?', days.days.ago).delete_all
      puts "Cleaned up #{count} dead letters older than #{days} days"
    end
  end
end
