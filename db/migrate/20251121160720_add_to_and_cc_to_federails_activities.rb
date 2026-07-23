class AddToAndCcToFederailsActivities < ActiveRecord::Migration[7.2]
  def change
    add_column :federails_activities, :to, :string
    add_column :federails_activities, :cc, :string
  end
end
