class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActionController::ParameterMissing, with: :render_parameter_missing

  private

  def render_not_found
    render json: { errors: { base: [ "not found" ] } }, status: :not_found
  end

  def render_parameter_missing(error)
    render json: { errors: { error.param => [ I18n.t("errors.messages.blank") ] } }, status: :bad_request
  end

  def render_validation_errors(errors)
    render json: { errors: errors }, status: :unprocessable_content
  end
end
