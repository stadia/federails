class CreatePosts < ActiveRecord::Migration[7.1]
  def change
    create_table :posts do |t|
      t.string :title, null: false, default: nil
      t.text :content, null: false, default: nil
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
