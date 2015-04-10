class AddTotalToEbParse < ActiveRecord::Migration
  def change
    add_column :eb_parses, :total_avoided, :integer, default: 0
  end
end
