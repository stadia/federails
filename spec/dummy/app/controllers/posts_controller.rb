class PostsController < ApplicationController
  before_action :authenticate_user!, except: [:index, :show]
  before_action :set_post, only: [:show, :edit, :update, :destroy]

  # GET /posts or /posts.json
  def index
    @posts = Post.not_deleted
    render json: PostResource.new(@posts).serializable_hash if request.format.json?
  end

  # GET /posts/1 or /posts/1.json
  def show
    render json: PostResource.new(@post).serializable_hash if request.format.json?
  end

  # GET /posts/new
  def new
    @post = Post.new
  end

  # GET /posts/1/edit
  def edit; end

  # POST /posts or /posts.json
  def create
    @post = Post.new(post_params)
    @post.user = current_user

    respond_to do |format|
      if @post.save
        format.html { redirect_to post_url(@post), notice: 'Post was successfully created.' }
        format.json { render json: PostResource.new(@post).serializable_hash, status: :created, location: @post }
      else
        format.html { render :new, status: Federails::Utils::ResponseCodes::UNPROCESSABLE_CONTENT }
        format.json { render json: @post.errors, status: Federails::Utils::ResponseCodes::UNPROCESSABLE_CONTENT }
      end
    end
  end

  # PATCH/PUT /posts/1 or /posts/1.json
  def update
    respond_to do |format|
      if @post.update(post_params)
        format.html { redirect_to post_url(@post), notice: 'Post was successfully updated.' }
        format.json { render json: PostResource.new(@post).serializable_hash, status: :ok, location: @post }
      else
        format.html { render :edit, status: Federails::Utils::ResponseCodes::UNPROCESSABLE_CONTENT }
        format.json { render json: @post.errors, status: Federails::Utils::ResponseCodes::UNPROCESSABLE_CONTENT }
      end
    end
  end

  # DELETE /posts/1 or /posts/1.json
  def destroy
    @post.soft_delete!

    respond_to do |format|
      format.html { redirect_to posts_url, notice: 'Post was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_post
    @post = Post.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def post_params
    params.require(:post).permit(:title, :content, :user_id)
  end
end
