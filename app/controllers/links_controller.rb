class LinksController < ApplicationController
  before_action :load_profile
  before_action :load_link, only: [ :edit, :update, :destroy ]

  def index
    # Enabled links are drag-reorderable; disabled ones sit in their own list.
    @enabled_links  = @profile.links.enabled.ordered
    @disabled_links = @profile.links.where(enabled: false).ordered
  end

  def new
    @link = @profile.links.build
  end

  def edit
  end

  def create
    @link = @profile.links.build(link_params)
    if @link.save
      redirect_to profile_path(@profile)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @link.update(link_params)
      redirect_to profile_path(@profile)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @link.destroy
    redirect_to profile_links_path(@profile)
  end

  # Persist a new order from drag-and-drop in the links index.
  def reorder
    Array(params[:ids]).each_with_index do |id, i|
      @profile.links.where(id: id).update_all(position: i)
    end
    head :ok
  end

  private

  def load_profile
    @profile = Profile.find_by!(slug: params[:slug])
  end

  def load_link
    @link = @profile.links.find(params[:id])
  end

  def link_params
    params.require(:link).permit(:title, :description, :icon, :url, :position, :enabled)
  end
end
