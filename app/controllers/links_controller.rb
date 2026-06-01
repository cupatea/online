class LinksController < ApplicationController
  before_action :load_profile
  before_action :load_link, only: [ :edit, :update, :destroy ]

  def index
    @links = @profile.links.ordered
  end

  def new
    @link = @profile.links.build
  end

  def edit
  end

  def create
    @link = @profile.links.build(link_params)
    if @link.save
      redirect_to profile_links_path(@profile), notice: "Link added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @link.update(link_params)
      redirect_to profile_links_path(@profile), notice: "Link updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @link.destroy
    redirect_to profile_links_path(@profile), notice: "Link removed."
  end

  private

  def load_profile
    @profile = Profile.find_by!(slug: params[:slug])
  end

  def load_link
    @link = @profile.links.find(params[:id])
  end

  def link_params
    params.require(:link).permit(:title, :description, :icon, :url, :position)
  end
end
