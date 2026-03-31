class CreateFederailsFeaturedTags < ActiveRecord::Migration[7.0]
  def change
    create_table :federails_featured_tags do |t|
      t.references :actor, null: false, foreign_key: { to_table: :federails_actors }
      t.string :name, null: false
      t.timestamps
    end
    add_index :federails_featured_tags, [:actor_id, :name], unique: true
  end
end
