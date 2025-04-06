class AddDeletedAtToPostsAndComments < ActiveRecord::Migration[7.2]
  def change
    add_column :posts, :deleted_at, :datetime, null: true, default: nil
    add_column :comments, :deleted_at, :datetime, null: true, default: nil
  end
end
