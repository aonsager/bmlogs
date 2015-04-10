class AddHashToGuardParses < ActiveRecord::Migration
  def change
    add_column :guard_parses, :damage_hash, :text, default: {}.to_yaml
  end
end
