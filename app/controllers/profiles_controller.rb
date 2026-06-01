class ProfilesController < ApplicationController
  before_action :load_profile, only: [ :show, :edit, :update, :destroy ]

  def show
    @links = @profile.links.enabled.ordered
  end

  def new
    @profile = Profile.new
  end

  def create
    @profile = Profile.new(profile_params)
    if @profile.save
      redirect_to profile_links_path(@profile)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @profile.update(profile_params)
      redirect_to edit_profile_path(@profile)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @profile.destroy
    redirect_to root_path, notice: "Profile removed."
  end

  private

  def load_profile
    @profile = Profile.find_by!(slug: params[:slug])
  end

  def profile_params
    params.require(:profile).permit(:name)
  end
end
