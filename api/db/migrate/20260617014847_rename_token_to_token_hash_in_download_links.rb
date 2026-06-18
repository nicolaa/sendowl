class RenameTokenToTokenHashInDownloadLinks < ActiveRecord::Migration[8.0]
  def change
    rename_column :download_links, :token, :token_hash
  end
end
