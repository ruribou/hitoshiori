module Api
  module V1
    class TagsController < ApplicationController
      def index
        tags = Tag.order(:name)

        render json: { tags: TagPresenter.serialize_collection(tags) }
      end
    end
  end
end
