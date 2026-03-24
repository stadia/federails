class PostResource
  include Alba::Resource

  attributes :id, :title, :content, :user_id, :created_at, :updated_at
end
