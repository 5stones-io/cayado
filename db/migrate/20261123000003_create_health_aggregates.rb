# Dashboard and Congregation: whole-church numbers only, never people.
# Typed in by an admin for now; Planning Center fills the same rows later
# (source "pco"). A congregation snapshot can be pinned to a sermon week so
# the preacher sees who's in the room that Sunday.
class CreateHealthAggregates < ActiveRecord::Migration[7.2]
  def change
    # One row per Sunday. A null number is "not counted", not zero.
    create_table :cayado_weekly_metrics do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.date    :week_of, null: false
      t.integer :attendance
      t.integer :first_time_guests
      t.bigint  :giving_cents
      # [{name, value}] in display order ("Adults", "Kids", "Online"…):
      # Planning Center's own groupings, not Cayado's ministries.
      t.jsonb   :by_ministry, null: false, default: []
      # A chart annotation: "Easter", "Vision Sunday".
      t.string  :label
      # manual | pco
      t.string  :source, null: false, default: "manual"
      t.timestamps
    end
    add_index :cayado_weekly_metrics, [:church_id, :week_of], unique: true

    create_table :cayado_budgets do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.integer :year, null: false
      t.bigint  :monthly_cents, null: false
      t.timestamps
    end
    add_index :cayado_budgets, [:church_id, :year], unique: true

    create_table :cayado_congregation_snapshots do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.date    :taken_on, null: false
      t.integer :households
      # [{label, pct}]
      t.jsonb   :life_stages, null: false, default: []
      # [{label, count}] over the last 90 days: births, funerals, baptisms…
      t.jsonb   :season_markers, null: false, default: []
      # What the pastor wants to remember about the room.
      t.text    :note
      t.string  :source, null: false, default: "manual"
      t.timestamps
    end
    add_index :cayado_congregation_snapshots, [:church_id, :taken_on]

    add_reference :cayado_sermon_weeks, :congregation_snapshot,
                  foreign_key: { to_table: :cayado_congregation_snapshots, on_delete: :nullify }
  end
end
