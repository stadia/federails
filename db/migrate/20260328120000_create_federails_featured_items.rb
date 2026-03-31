class CreateFederailsFeaturedItems < ActiveRecord::Migration[7.0]
  def change
    create_table :federails_featured_items do |t|
      t.references :actor, null: false, foreign_key: { to_table: :federails_actors }
      t.string :federated_url, null: false
      t.timestamps
    end
    add_index :federails_featured_items, [:actor_id, :federated_url], unique: true
  end
end
