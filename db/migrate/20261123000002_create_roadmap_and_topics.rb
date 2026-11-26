# The Roadmap and Topics screens. Sermon series already sit on the roadmap
# (their own lane, read from cayado_sermon_series), so roadmap items are the
# other three lanes: major events, outreach, ministry initiatives. Docs attach
# to either an item or a series. Topics are the church's teaching library;
# each series carries some of them with a weight of 1–3 (the heatmap).
class CreateRoadmapAndTopics < ActiveRecord::Migration[7.2]
  def change
    create_table :cayado_roadmap_items do |t|
      t.references :church, null: false, foreign_key: true, index: false
      # major_event | outreach | ministry_initiative
      t.string :lane,  null: false
      t.string :title, null: false
      t.date   :starts_on, null: false
      t.date   :ends_on,   null: false
      t.string :color, null: false, default: "ink"
      t.references :owner_membership, foreign_key: { to_table: :memberships, on_delete: :nullify }
      t.text :notes
      # What it advances: a pillar, optionally one of its moves
      # ("Summer Nights" advances Reach without a particular move).
      t.references :pillar, foreign_key: { to_table: :cayado_pillars, on_delete: :nullify }
      t.references :move,   foreign_key: { to_table: :cayado_moves, on_delete: :nullify }
      t.timestamps
    end
    add_index :cayado_roadmap_items, [:church_id, :starts_on]

    # A Google Doc/Sheet/Slide/Drive folder (or any link) on an item or series.
    create_table :cayado_attachments do |t|
      t.references :church, null: false, foreign_key: true
      t.references :attachable, polymorphic: true, null: false
      t.string :title, null: false
      t.string :url,   null: false
      # doc | sheet | slide | folder
      t.string :kind,  null: false, default: "doc"
      t.references :owner_membership, foreign_key: { to_table: :memberships, on_delete: :nullify }
      t.text :tags, array: true, null: false, default: []
      t.timestamps
    end

    create_table :cayado_topics do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.string  :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :cayado_topics, [:church_id, :name], unique: true

    create_table :cayado_series_topics do |t|
      t.references :sermon_series, null: false, foreign_key: { to_table: :cayado_sermon_series, on_delete: :cascade }, index: false
      t.references :topic, null: false, foreign_key: { to_table: :cayado_topics, on_delete: :cascade }
      t.integer :weight, null: false
      t.timestamps
    end
    add_index :cayado_series_topics, [:sermon_series_id, :topic_id], unique: true
    add_check_constraint :cayado_series_topics, "weight BETWEEN 1 AND 3", name: "series_topic_weight_1_to_3"
  end
end
