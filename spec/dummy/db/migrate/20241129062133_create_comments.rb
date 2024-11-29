class CreateComments < ActiveRecord::Migration[7.1]
  def change
    create_table :comments do |t|
      t.text :content, null: false, default: nil
      t.references :user, null: false, foreign_key: true
      t.references :post, null: true, foreign_key: true, comment: 'Null allowed for responses to another comment'
      t.references :parent, foreign_key: { to_table: :comments }

      t.timestamps
    end
  end
end
