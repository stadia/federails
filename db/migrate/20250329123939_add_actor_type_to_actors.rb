class AddActorTypeToActors < ActiveRecord::Migration[7.2]
  def change
    add_column :federails_actors, :actor_type, :string, null: true
  end
end
