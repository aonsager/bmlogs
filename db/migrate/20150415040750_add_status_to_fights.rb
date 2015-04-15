class AddStatusToFights < ActiveRecord::Migration
  def change
    remove_column :fights, :processed
    add_column :fights, :status, :integer, default: 0
  end
end
