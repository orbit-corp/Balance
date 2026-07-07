class ShortLinksController < ApplicationController
  def new
    @short_link = ShortLink.new
  end

  def create
    @short_link = ShortLink.new(long_url: params[:long_url])

    if @short_link.save
      flash[:short_url] = short_link_url(@short_link.short_code)
      redirect_to root_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    short_link = ShortLink.find_by(short_code: params[:short_code])

    if short_link
      redirect_to short_link.long_url, status: :found, allow_other_host: true
    else
      head :not_found
    end
  end

  private

  def short_link_url(code)
    "#{request.base_url}/#{code}"
  end
end
