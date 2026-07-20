class AddKeypairToActors < ActiveRecord::Migration[7.0]
  def change
    change_table :fedipub_actors do |t|
      t.text :public_key
      t.text :private_key
    end
  end
end
