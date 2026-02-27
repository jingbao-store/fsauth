class ApplicationsController < ApplicationController
  before_action :authenticate_user!, except: [:skill]
  before_action :set_application, only: [:show, :edit, :update, :destroy]
  before_action :set_application_for_skill, only: [:skill]

  def index
    @applications = Current.user.applications.order(created_at: :desc)
  end

  def show
  end

  def new
    @application = Application.new
  end

  def create
    @application = Current.user.applications.build(application_params)
    if @application.save
      redirect_to application_path(@application), notice: "Application created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @application.update(application_params)
      redirect_to application_path(@application), notice: "Application updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @application.destroy
    redirect_to applications_path, notice: "Application deleted successfully."
  end

  # GET /applications/:id/SKILL.md (public)
  def skill
    unless @application
      render plain: 'Application not found', status: :not_found
      return
    end

    # Render markdown template directly
    markdown_content = render_to_string(
      template: 'applications/skill',
      layout: false,
      formats: [:md]
    )
    
    render plain: markdown_content, content_type: 'text/markdown; charset=utf-8'
  end

  private

  def set_application
    @application = Current.user.applications.find(params[:id])
  end

  def set_application_for_skill
    @application = Application.find_by(id: params[:id])
  end

  def application_params
    params.require(:application).permit(:name, :feishu_app_id, :feishu_app_secret)
  end
end
