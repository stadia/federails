class AddLocalToActors < ActiveRecord::Migration[7.0]
  def change
    add_column :fedipub_actors, :local, :boolean, null: false, default: false

    reversible do |dir|
      dir.up do
        exec_update 'UPDATE fedipub_actors SET local=true WHERE entity_type IS NOT NULL'
      end
    end
  end
end
