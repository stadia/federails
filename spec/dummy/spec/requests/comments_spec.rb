require 'rails_helper'

RSpec.describe '/comments', type: :request do
  let(:user) { FactoryBot.create :user }
  let!(:comment) { FactoryBot.create :comment, user: user }

  let(:valid_attributes) do
    post = FactoryBot.create :post, user: user
    FactoryBot.attributes_for :comment, post_id: post.id
  end

  let(:invalid_attributes) do
    { content: '' }
  end

  before { sign_in user }

  describe 'GET /edit' do
    it 'renders a successful response' do
      get edit_comment_url(comment)
      expect(response).to be_successful
    end
  end

  describe 'POST /create' do
    context 'with valid parameters' do
      it 'creates a new Comment' do
        expect do
          post comments_url, params: { comment: valid_attributes }
        end.to change(Comment, :count).by(1)
      end

      it 'redirects to the post' do
        post comments_url, params: { comment: valid_attributes }
        expect(response).to redirect_to(post_url(Comment.last.post_id))
      end
    end

    context 'with invalid parameters' do
      it 'does not create a new Comment' do
        expect do
          post comments_url, params: { comment: invalid_attributes }
        end.not_to change(Comment, :count)
      end

      it 'redirects to the posts list)' do
        post comments_url, params: { comment: invalid_attributes }
        expect(response).to redirect_to(posts_url)
      end
    end
  end

  describe 'PATCH /update' do
    context 'with valid parameters' do
      let(:new_attributes) do
        { content: 'New content' }
      end

      it 'updates the requested comment' do
        patch comment_url(comment), params: { comment: new_attributes }
        comment.reload
        expect(comment.content).to eq 'New content'
      end

      it 'redirects to the post' do
        patch comment_url(comment), params: { comment: new_attributes }
        comment.reload
        expect(response).to redirect_to(post_url(comment.post))
      end
    end

    context 'with invalid parameters' do
      it "renders a response with 422 status (i.e. to display the 'edit' template)" do
        comment = FactoryBot.create :comment, user: user
        patch comment_url(comment), params: { comment: invalid_attributes }
        expect(response).to have_http_status(Federails::Utils::ResponseCodes::UNPROCESSABLE_CONTENT)
      end
    end
  end

  describe 'DELETE /destroy' do
    it 'destroys the requested comment' do
      expect do
        delete comment_url(comment)
      end.to change { Comment.deleted.count }.by(1)
    end

    it 'redirects to the post' do
      delete comment_url(comment)
      expect(response).to redirect_to(post_url(comment.post))
    end
  end
end
