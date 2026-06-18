class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :name
      t.string :file_placeholder
      t.integer :expiry_hours
      t.integer :max_download_count

      t.timestamps
    end
  end
end
