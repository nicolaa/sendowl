class CreateDownloadLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :download_links do |t|
      t.references :order, null: false, foreign_key: true
      t.string :token
      t.datetime :expires_at
      t.integer :download_count

      t.timestamps
    end
    add_index :download_links, :token, unique: true
  end
end
