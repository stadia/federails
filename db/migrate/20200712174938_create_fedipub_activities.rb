class CreateFederailsActivities < ActiveRecord::Migration[7.0]
  def change
    create_table :fedipub_activities do |t|
      t.references :entity, polymorphic: true, null: false
      t.string :action, null: false, default: nil
      t.references :actor, null: false, foreign_key: { to_table: :fedipub_actors }

      t.timestamps
    end
  end
end
