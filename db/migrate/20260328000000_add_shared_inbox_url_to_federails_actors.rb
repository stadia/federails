class AddSharedInboxUrlToFederailsActors < ActiveRecord::Migration[7.2]
  def change
    add_column :federails_actors, :shared_inbox_url, :string
  end
end
