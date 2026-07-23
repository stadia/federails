class RenameFederailsFieldsToFedipub < ActiveRecord::Migration[7.2]
  def change
    rename_column :posts, 'federails_actor_id', 'fedipub_actor_id'
    rename_column :comments, 'federails_actor_id', 'fedipub_actor_id'
  end
end
