# Same columns spirely uses for these (minus kids-ministry ones), so SSO or
# a shared core gem can join them up later without a rewrite.
class CreateChurchesMembershipsAndDomains < ActiveRecord::Migration[7.2]
  def change
    create_table :churches do |t|
      t.string :slug,         null: false
      t.string :name,         null: false
      t.string :display_name
      t.string :status,       null: false, default: "pending"
      t.string :timezone
      t.string :city
      t.string :state
      t.timestamps
    end
    add_index :churches, :slug, unique: true

    create_table :memberships do |t|
      t.references :account, null: false, foreign_key: true, index: false
      t.references :church,  null: false, foreign_key: true
      t.string :role,  null: false, default: "member"
      # What the person does there, shown next to their name: "Kids Pastor".
      t.string :title
      t.timestamps
    end
    add_index :memberships, [:account_id, :church_id], unique: true

    create_table :custom_domains do |t|
      t.references :church, null: false, foreign_key: true
      t.string   :hostname,           null: false
      t.datetime :verified_at
      t.string   :verification_token, null: false
      t.boolean  :primary,            null: false, default: false
      t.timestamps
    end
    add_index :custom_domains, :hostname, unique: true
  end
end
