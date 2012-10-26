module Api
  module V1
    class ResponsesController < ApplicationController
      def create
        response = Response.new
        response.user_id = response.organization_id = 0 # temporary fix for no login on mobile
        answers_attributes = params[:response].delete(:answers_attributes)
        response.update_attributes(params[:response]) # Response isn't created before the answers, so we need to create the answers after this.
        response.validating if params[:response][:status] == "complete"
        response.update_attributes({:answers_attributes => answers_attributes}) if response.save

        if response.incomplete? && response.valid?
          render :json => response.to_json(:methods => :answers)
        elsif response.validating? && response.valid?
          response.complete
          render :nothing => true
        else
          response_json = response.to_json(:methods => :answers)
          response.destroy
          render :json => response_json, :status => :bad_request
        end
      end

      def update
        response = Response.find(params[:id])
        # TODO
        # validate as appropriate
        # merge response and its answers based on update time in model
        # follow same logic as create for giving back response with answers
        response.validating
        if response.update_attributes(params[:response])
          response.complete
          render :json => response.to_json
        else
          response.complete
          render :nothing => true, :status => :bad_request
        end
      end
    end
  end
end
