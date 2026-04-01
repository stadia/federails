# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_28_120001) do
  create_table "comments", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.integer "federails_actor_id"
    t.string "federated_url"
    t.integer "parent_id"
    t.integer "post_id"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["federails_actor_id"], name: "index_comments_on_federails_actor_id"
    t.index ["parent_id"], name: "index_comments_on_parent_id"
    t.index ["post_id"], name: "index_comments_on_post_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "federails_activities", force: :cascade do |t|
    t.string "action", null: false
    t.integer "actor_id", null: false
    t.string "audience"
    t.string "bcc"
    t.string "bto"
    t.string "cc"
    t.datetime "created_at", null: false
    t.integer "entity_id", null: false
    t.string "entity_type", null: false
    t.string "federated_url"
    t.string "to"
    t.datetime "updated_at", null: false
    t.string "uuid"
    t.index ["actor_id"], name: "index_federails_activities_on_actor_id"
    t.index ["entity_type", "entity_id"], name: "index_federails_activities_on_entity"
    t.index ["federated_url"], name: "index_federails_activities_on_federated_url", unique: true
    t.index ["uuid"], name: "index_federails_activities_on_uuid", unique: true
  end

  create_table "federails_actors", force: :cascade do |t|
    t.string "actor_type"
    t.datetime "created_at", null: false
    t.integer "entity_id"
    t.string "entity_type"
    t.json "extensions"
    t.string "federated_url"
    t.string "followers_url"
    t.string "followings_url"
    t.string "inbox_url"
    t.boolean "local", default: false, null: false
    t.string "name"
    t.string "outbox_url"
    t.text "private_key"
    t.string "profile_url"
    t.text "public_key"
    t.string "server"
    t.datetime "tombstoned_at"
    t.datetime "updated_at", null: false
    t.string "username"
    t.string "uuid"
    t.index ["entity_type", "entity_id"], name: "index_federails_actors_on_entity", unique: true
    t.index ["federated_url"], name: "index_federails_actors_on_federated_url", unique: true
    t.index ["uuid"], name: "index_federails_actors_on_uuid", unique: true
  end

  create_table "federails_blocks", force: :cascade do |t|
    t.integer "actor_id", null: false
    t.datetime "created_at", null: false
    t.integer "target_actor_id", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id", "target_actor_id"], name: "index_federails_blocks_on_actor_id_and_target_actor_id", unique: true
    t.index ["actor_id"], name: "index_federails_blocks_on_actor_id"
    t.index ["target_actor_id"], name: "index_federails_blocks_on_target_actor_id"
  end

  create_table "federails_featured_items", force: :cascade do |t|
    t.integer "actor_id", null: false
    t.datetime "created_at", null: false
    t.string "federated_url", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id", "federated_url"], name: "index_federails_featured_items_on_actor_id_and_federated_url", unique: true
    t.index ["actor_id"], name: "index_federails_featured_items_on_actor_id"
  end

  create_table "federails_featured_tags", force: :cascade do |t|
    t.integer "actor_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id", "name"], name: "index_federails_featured_tags_on_actor_id_and_name", unique: true
    t.index ["actor_id"], name: "index_federails_featured_tags_on_actor_id"
  end

  create_table "federails_followings", force: :cascade do |t|
    t.integer "actor_id", null: false
    t.datetime "created_at", null: false
    t.string "federated_url"
    t.integer "status", default: 0
    t.integer "target_actor_id", null: false
    t.datetime "updated_at", null: false
    t.string "uuid"
    t.index ["actor_id", "target_actor_id"], name: "index_federails_followings_on_actor_id_and_target_actor_id", unique: true
    t.index ["actor_id"], name: "index_federails_followings_on_actor_id"
    t.index ["target_actor_id"], name: "index_federails_followings_on_target_actor_id"
    t.index ["uuid"], name: "index_federails_followings_on_uuid", unique: true
  end

  create_table "federails_hosts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "domain", null: false
    t.string "nodeinfo_url"
    t.text "protocols", default: "[]"
    t.text "services", default: "{}"
    t.string "software_name"
    t.string "software_version"
    t.datetime "updated_at", null: false
    t.index ["domain"], name: "index_federails_hosts_on_domain", unique: true
  end

  create_table "posts", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.integer "federails_actor_id"
    t.string "federated_url"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["federails_actor_id"], name: "index_posts_on_federails_actor_id"
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "comments", "comments", column: "parent_id"
  add_foreign_key "comments", "federails_actors"
  add_foreign_key "comments", "posts"
  add_foreign_key "comments", "users"
  add_foreign_key "federails_activities", "federails_actors", column: "actor_id"
  add_foreign_key "federails_blocks", "federails_actors", column: "actor_id"
  add_foreign_key "federails_blocks", "federails_actors", column: "target_actor_id"
  add_foreign_key "federails_featured_items", "federails_actors", column: "actor_id"
  add_foreign_key "federails_featured_tags", "federails_actors", column: "actor_id"
  add_foreign_key "federails_followings", "federails_actors", column: "actor_id"
  add_foreign_key "federails_followings", "federails_actors", column: "target_actor_id"
  add_foreign_key "posts", "federails_actors"
  add_foreign_key "posts", "users"
end
