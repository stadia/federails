require 'rails_helper'

RSpec.describe '/posts', type: :request do
  let(:user) { FactoryBot.create :user }
  let!(:article) { FactoryBot.create :post, user: user }

  let(:valid_attributes) do
    FactoryBot.attributes_for :post
  end

  let(:invalid_attributes) do
    { title: '' }
  end

  before { sign_in user }

  describe 'GET /index' do
    it 'renders a successful response' do
      get posts_url
      expect(response).to be_successful
    end
  end

  describe 'GET /show' do
    it 'renders a successful response' do
      get post_url(article)
      expect(response).to be_successful
    end
  end

  describe 'GET /new' do
    it 'renders a successful response' do
      get new_post_url
      expect(response).to be_successful
    end
  end

  describe 'GET /edit' do
    it 'renders a successful response' do
      get edit_post_url(article)
      expect(response).to be_successful
    end
  end

  describe 'POST /create' do
    context 'with valid parameters' do
      it 'creates a new Post' do
        expect do
          post posts_url, params: { post: valid_attributes }
        end.to change(Post, :count).by(1)
      end

      it 'redirects to the created post' do
        post posts_url, params: { post: valid_attributes }
        expect(response).to redirect_to(post_url(Post.last))
      end
    end

    context 'with invalid parameters' do
      it 'does not create a new Post' do
        expect do
          post posts_url, params: { post: invalid_attributes }
        end.not_to change(Post, :count)
      end

      it "renders a response with 422 status (i.e. to display the 'new' template)" do
        post posts_url, params: { post: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PATCH /update' do
    context 'with valid parameters' do
      let(:new_attributes) do
        { title: 'New title' }
      end

      it 'updates the requested post' do
        patch post_url(article), params: { post: new_attributes }
        article.reload
        expect(article.title).to eq 'New title'
      end

      it 'redirects to the post' do
        patch post_url(article), params: { post: new_attributes }
        article.reload
        expect(response).to redirect_to(post_url(article))
      end
    end

    context 'with invalid parameters' do
      it "renders a response with 422 status (i.e. to display the 'edit' template)" do
        patch post_url(article), params: { post: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'DELETE /destroy' do
    it 'destroys the requested post' do
      expect do
        delete post_url(article)
      end.to change { Post.deleted.count }.by(1)
    end

    it 'redirects to the posts list' do
      delete post_url(article)
      expect(response).to redirect_to(posts_url)
    end
  end
end
