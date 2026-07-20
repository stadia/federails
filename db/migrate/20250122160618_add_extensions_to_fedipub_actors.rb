class AddExtensionsToFederailsActors < ActiveRecord::Migration[7.1]
  def change
    add_column :fedipub_actors, :extensions, :json, default: nil, null: true
  end
end
