class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid

  private

  def render_not_found
    render json: { errors: { base: [ "not found" ] } }, status: :not_found
  end

  def render_record_invalid(error)
    render_validation_errors(error.record.errors.to_hash)
  end

  def render_validation_errors(errors)
    render json: { errors: errors }, status: :unprocessable_entity
  end
end
