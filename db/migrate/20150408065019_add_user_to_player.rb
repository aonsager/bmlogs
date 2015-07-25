class AddUserToPlayer < ActiveRecord::Migration
  def change
    create_table :user_to_players do |t|
      t.text     :user_id
      t.integer  :player_id, null: false
      t.text     :player_name
      t.timestamps
    end
  end
end
