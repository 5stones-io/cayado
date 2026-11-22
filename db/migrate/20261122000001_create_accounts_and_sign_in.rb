# Accounts and the tables Rodauth needs for password + authenticator sign-in
# (copied from spirely-cloud, minus magic links). Password hashes live
# outside `accounts`; account_password_codes is the :password_code feature's
# emailed 6-digit code (one live code per account).
class CreateAccountsAndSignIn < ActiveRecord::Migration[7.2]
  def change
    enable_extension "pgcrypto"

    create_table :accounts do |t|
      t.string  :email,          null: false
      t.string  :first_name
      t.string  :last_name
      t.integer :status_id,      null: false, default: 2 # 1=unverified 2=verified 3=closed
      t.boolean :platform_admin, null: false, default: false
      t.timestamps
    end
    add_index :accounts, :email, unique: true, where: "status_id != 3"

    create_table :account_password_hashes, id: false do |t|
      t.bigint :id, null: false, primary_key: true
      t.string :password_hash, null: false
    end
    add_foreign_key :account_password_hashes, :accounts, column: :id

    create_table :account_login_failures, id: false do |t|
      t.bigint  :id,     null: false, primary_key: true
      t.integer :number, null: false, default: 1
    end
    add_foreign_key :account_login_failures, :accounts, column: :id

    create_table :account_lockouts, id: false do |t|
      t.bigint   :id,       null: false, primary_key: true
      t.string   :key,      null: false
      t.datetime :deadline, null: false
      t.datetime :email_last_sent
    end
    add_foreign_key :account_lockouts, :accounts, column: :id

    create_table :account_otp_keys, id: false do |t|
      t.bigint   :id,           null: false, primary_key: true
      t.string   :key,          null: false
      t.integer  :num_failures, null: false, default: 0
      t.datetime :last_use,     null: false, default: -> { "CURRENT_TIMESTAMP" }
    end
    add_foreign_key :account_otp_keys, :accounts, column: :id

    create_table :account_recovery_codes, primary_key: [:id, :code] do |t|
      t.bigint :id
      t.string :code
    end
    add_foreign_key :account_recovery_codes, :accounts, column: :id

    create_table :account_password_codes, id: false do |t|
      t.bigint   :id,          null: false, primary_key: true
      t.string   :code_digest, null: false
      t.datetime :deadline,    null: false
      t.integer  :attempts,    null: false, default: 0
      t.datetime :created_at,  null: false, default: -> { "CURRENT_TIMESTAMP" }
    end
    add_foreign_key :account_password_codes, :accounts, column: :id
  end
end
