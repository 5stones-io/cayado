# What the team did, for the mobile Activity tab: comments, plans written
# and Notify team heads-ups. A row per thing that happened; who has seen
# what is one timestamp per membership (everything after it is unread).
class CreateActivityEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :cayado_activity_events do |t|
      t.references :church, null: false, foreign_key: true, index: false
      # Nullified when they leave the staff: the event stays, actor unknown.
      t.references :actor_membership, foreign_key: { to_table: :memberships, on_delete: :nullify }
      # comment_added | plan_saved | team_notified
      t.string :kind, null: false
      t.references :sermon_series, foreign_key: { to_table: :cayado_sermon_series, on_delete: :cascade }
      t.references :sermon_week,   foreign_key: { to_table: :cayado_sermon_weeks, on_delete: :cascade }
      # excerpt; ministry_key/name for plans; subject + recipient_ids for heads-ups.
      t.jsonb :data, null: false, default: {}
      t.timestamps
    end
    add_index :cayado_activity_events, [:church_id, :id]

    add_column :memberships, :activity_seen_at, :datetime
  end
end
