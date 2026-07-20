class AddResultAndInstrumentToFederailsActivities < ActiveRecord::Migration[7.2]
  def change
    add_column :fedipub_activities, :result, :string
    add_column :fedipub_activities, :instrument, :string
  end
end
