class ChangeExpiryHoursToFloatInProducts < ActiveRecord::Migration[8.1]
  def change
    change_column :products, :expiry_hours, :float
  end
end
