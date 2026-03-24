class CommentResource
  include Alba::Resource

  attributes :id, :content, :user_id, :post_id, :parent_id, :created_at, :updated_at
end
