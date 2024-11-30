class AddFederationToPostsAndComments < ActiveRecord::Migration[7.1]
  def change
    [:posts, :comments].each do |table|
      add_column table, :federated_url, :string, null: true, default: nil
      add_reference table, :federails_actor, null: true, foreign_key: true
      change_column_null table, :user_id, true
    end
  end
end
