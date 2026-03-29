class CreateFederailsDeadLetters < ActiveRecord::Migration[7.0]
  def change
    create_table :federails_dead_letters do |t|
      t.references :activity, null: false, foreign_key: { to_table: :federails_activities }
      t.string :target_inbox, null: false
      t.string :last_error
      t.integer :attempts, null: false, default: 0
      t.datetime :last_attempted_at
      t.timestamps
    end
    add_index :federails_dead_letters, [:activity_id, :target_inbox], unique: true
  end
end
