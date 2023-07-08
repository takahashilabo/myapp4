class BookmarksController < ApplicationController
  def index
    @bookmarks = Bookmark.all
  end

  def new
    @bookmark = Bookmark.new
  end

  def create
    bookmark = Bookmark.new(title: params[:bookmarks][:title], url: params[:bookmarks][:url])
    bookmark.save
    redirect_to '/bookmarks/index'
  end
end
