require 'will_paginate/array'

class SurveysController < ApplicationController
  load_and_authorize_resource :only => :index

  before_filter :require_cso_admin, :except => [:index, :build]
  before_filter :survey_unpublished, :only => [:build]

  def index
    @surveys ||= []
    @surveys = @surveys.select { |survey| survey.published.to_s == params[:published] } if params[:published].present?
    @surveys = @surveys.paginate(:page => params[:page], :per_page => 10)
    if access_token.present?
      organizations = access_token.get('api/organizations').parsed
      @organization_names = organizations.reduce({}) do |hash, org|
        hash[org['id']] = org['name']
        hash
      end
    end
  end

  def destroy
    survey = Survey.find(params[:id])
    survey.destroy
    flash[:notice] = t "flash.survey_deleted"
    redirect_to(surveys_path)
  end

  def new
    @survey = Survey.new()
  end

  def create
    @survey = Survey.new(params[:survey])
    @survey.organization_id = session[:user_info][:org_id]

    if @survey.save
      flash[:notice] = t "flash.survey_created"
      redirect_to surveys_build_path(:id => @survey.id)
    else
      render :new
    end
  end

  def build
    @survey = Survey.find(params[:id])
  end

  def publish
    @survey = Survey.find(params[:survey_id])
    @users = access_token.get('api/organization_users').parsed
    @survey.publish
    redirect_to :back, :confirm => "Are you sure you want to publish this"
  end

  def share
    @survey = Survey.find(params[:survey_id])
    if @survey.published?
      @organizations = access_token.get('api/organizations').parsed
      @organizations.select!{ |org| org["id"] != @survey.organization_id }
    else
      redirect_to surveys_path
      flash[:error] = "Can not share an unpublished survey"
    end
  end

  def update_shared_orgs
    survey = Survey.find(params[:survey_id])
    params[:survey][:participating_organization_ids].each do |org_id|
      ParticipatingOrganization.create(:survey_id => survey.id, :organization_id => org_id)
    end
    survey.save
    flash[:notice] = "Successfully shared..."
    redirect_to surveys_path
  end

  private

  def require_cso_admin
    role = session[:user_info][:role] if user_currently_logged_in?
    unless role == 'cso_admin'
      flash[:error] = t "flash.not_authorized"
      redirect_to surveys_path
    end
  end

  def survey_unpublished
    survey = Survey.find(params[:id])
    if survey.published?
      flash[:error] = t "flash.edit_published_survey"
      redirect_to root_path
    end
  end
end
