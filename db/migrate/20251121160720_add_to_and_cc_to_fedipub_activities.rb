class AddToAndCcToFedipubActivities < ActiveRecord::Migration[7.2]
  def change
    add_column :fedipub_activities, :to, :string
    add_column :fedipub_activities, :cc, :string
  end
end
