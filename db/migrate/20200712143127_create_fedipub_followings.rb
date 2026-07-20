class CreateFederailsFollowings < ActiveRecord::Migration[7.0]
  def change
    create_table :fedipub_followings do |t|
      t.references :actor, null: false, foreign_key: { to_table: :fedipub_actors }
      t.references :target_actor, null: false, foreign_key: { to_table: :fedipub_actors }
      t.integer :status, default: 0
      t.string :federated_url

      t.timestamps

      t.index [:actor_id, :target_actor_id], unique: true
    end
  end
end
