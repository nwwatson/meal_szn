class ChangeActiveStorageAttachmentsRecordIdToString < ActiveRecord::Migration[8.1]
  def up
    change_column :active_storage_attachments, :record_id, :string, null: false
  end

  def down
    change_column :active_storage_attachments, :record_id, :bigint, null: false
  end
end
