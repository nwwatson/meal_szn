class BackfillUserSettings < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      INSERT INTO user_settings (id, user_id, timezone, email_frequency, unit_system, created_at, updated_at)
      SELECT
        lower(hex(randomblob(4)) || '-' || hex(randomblob(2)) || '-4' || substr(hex(randomblob(2)),2) || '-' || substr('89ab', abs(random()) % 4 + 1, 1) || substr(hex(randomblob(2)),2) || '-' || hex(randomblob(6))),
        users.id,
        NULL,
        0,
        0,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      FROM users
      LEFT JOIN user_settings ON user_settings.user_id = users.id
      WHERE user_settings.id IS NULL
        AND users.role != 3
    SQL
  end

  def down
    # No-op: cannot distinguish backfilled records from naturally created ones
  end
end
