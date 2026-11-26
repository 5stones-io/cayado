# The planning domain: a church's vision, its ministries, and sermon series
# with the week-by-week alignment each ministry plans against them. One
# table per thing on the Figma screens (Vision, Sermons, This Week).
# Tables are cayado_* (isolate_namespace prefixes Cayado:: models).
class CreatePlanningDomain < ActiveRecord::Migration[7.2]
  def change
    # One vision per church: "2026–2030 vision".
    create_table :cayado_visions do |t|
      t.references :church, null: false, foreign_key: true, index: { unique: true }
      t.string  :title, null: false
      t.string  :subtitle
      t.integer :start_year, null: false
      t.integer :end_year,   null: false
      t.timestamps
    end

    # Reach / Disciple / Send.
    create_table :cayado_pillars do |t|
      t.references :vision, null: false, foreign_key: { to_table: :cayado_visions }
      t.integer :position, null: false, default: 0
      t.string  :title, null: false
      t.text    :blurb
      t.string  :tone, null: false, default: "ink"
      t.timestamps
    end

    # A concrete commitment under a pillar: "Plant a second Sunday gathering".
    create_table :cayado_moves do |t|
      t.references :pillar, null: false, foreign_key: { to_table: :cayado_pillars }
      t.integer :position, null: false, default: 0
      t.text    :text, null: false
      t.timestamps
    end

    # Staff who may edit a pillar besides admins.
    create_table :cayado_pillar_editors do |t|
      t.references :pillar,     null: false, foreign_key: { to_table: :cayado_pillars }, index: false
      t.references :membership, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end
    add_index :cayado_pillar_editors, [:pillar_id, :membership_id], unique: true

    # The five-year ladder: 2027 "Year of Multiplication" + its goals.
    create_table :cayado_horizon_years do |t|
      t.references :vision, null: false, foreign_key: { to_table: :cayado_visions }, index: false
      t.integer :year, null: false
      t.string  :headline
      t.text    :goals, array: true, null: false, default: []
      t.timestamps
    end
    add_index :cayado_horizon_years, [:vision_id, :year], unique: true

    # Kids / Youth / Small Groups / Worship: the alignment slots on a week.
    create_table :cayado_ministries do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.string  :key,  null: false
      t.string  :name, null: false
      t.string  :color, null: false, default: "ink"
      t.references :lead_membership, foreign_key: { to_table: :memberships, on_delete: :nullify }
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :cayado_ministries, [:church_id, :key], unique: true

    create_table :cayado_sermon_series do |t|
      t.references :church, null: false, foreign_key: true
      t.string :title, null: false
      t.string :theme
      t.string :scripture
      t.date   :starts_on
      t.date   :ends_on
      t.references :owner_membership, foreign_key: { to_table: :memberships, on_delete: :nullify }
      # The vision move this series advances (AdvancesBadge).
      t.references :move, foreign_key: { to_table: :cayado_moves, on_delete: :nullify }
      t.timestamps
    end

    create_table :cayado_sermon_weeks do |t|
      t.references :sermon_series, null: false, foreign_key: { to_table: :cayado_sermon_series }
      t.integer :position, null: false, default: 0
      t.date    :preached_on, null: false
      t.string  :title
      t.string  :scripture
      t.text    :big_idea
      t.timestamps
    end
    add_index :cayado_sermon_weeks, :preached_on

    # A ministry's plan for one week. No row means "awaiting".
    create_table :cayado_alignment_plans do |t|
      t.references :sermon_week, null: false, foreign_key: { to_table: :cayado_sermon_weeks }, index: false
      t.references :ministry,    null: false, foreign_key: { to_table: :cayado_ministries }
      t.text   :body, null: false
      t.string :memory_verse
      t.references :updated_by_membership, foreign_key: { to_table: :memberships, on_delete: :nullify }
      t.timestamps
    end
    add_index :cayado_alignment_plans, [:sermon_week_id, :ministry_id], unique: true

    # The conversation on a week. Someone leaving the staff keeps their
    # comments (membership nulled; shown as a former teammate).
    create_table :cayado_comments do |t|
      t.references :sermon_week, null: false, foreign_key: { to_table: :cayado_sermon_weeks }
      t.references :membership,  foreign_key: { on_delete: :nullify }
      t.text :body, null: false
      t.timestamps
    end
  end
end
