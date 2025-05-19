class CommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_comment, only: [:edit, :update, :destroy]

  # GET /comments/1/edit
  def edit; end

  # POST /comments or /comments.json
  def create # rubocop:disable Metrics/AbcSize
    @comment = Comment.new(comment_params)
    @comment.user = current_user

    respond_to do |format|
      if @comment.save
        format.html { redirect_to post_url(@comment.post), notice: 'Comment was successfully created.' }
        format.json { render :show, status: :created, location: @comment }
      else
        # Redirect and lose form content? Well, it's a dummy app.
        format.html { redirect_to posts_url, notice: 'Invalid comment, try again' }
        format.json { render json: @comment.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /comments/1 or /comments/1.json
  def update
    respond_to do |format|
      if @comment.update(comment_params)
        format.html { redirect_to post_url(@comment.post), notice: 'Comment was successfully updated.' }
        format.json { render :show, status: :ok, location: @comment }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @comment.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /comments/1 or /comments/1.json
  def destroy
    @comment.soft_delete!

    respond_to do |format|
      format.html { redirect_to post_url(@comment.post), notice: 'Comment was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_comment
    @comment = Comment.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def comment_params
    params.require(:comment).permit(:content, :user_id, :post_id, :parent_id)
  end
end
