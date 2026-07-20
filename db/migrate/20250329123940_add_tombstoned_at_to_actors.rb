class AddTombstonedAtToActors < ActiveRecord::Migration[7.0]
  def change
    add_column :fedipub_actors, :tombstoned_at, :datetime, default: nil
  end
end
