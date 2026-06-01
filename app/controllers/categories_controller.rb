class CategoriesController < ApplicationController
  before_action :load_profile
  before_action :load_category, only: [ :edit, :update, :destroy ]

  def index
    @categories = @profile.categories.ordered
  end

  def new
    @category = @profile.categories.build
  end

  def create
    @category = @profile.categories.build(category_params)
    @category.position = @profile.categories.maximum(:position).to_i + 1
    if @category.save
      redirect_to profile_categories_path(@profile)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @category.update(category_params)
      redirect_to profile_categories_path(@profile)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Removing a category leaves its links in place (dependent: :nullify).
  def destroy
    @category.destroy
    redirect_to profile_categories_path(@profile)
  end

  def reorder
    Array(params[:ids]).each_with_index do |id, i|
      @profile.categories.where(id: id).update_all(position: i)
    end
    head :ok
  end

  private

  def load_profile
    @profile = Profile.find_by!(slug: params[:slug])
  end

  def load_category
    @category = @profile.categories.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:name)
  end
end
