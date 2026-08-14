module Api
  module V1
    class TagsController < ApplicationController
      def index
        tags = Tag.order(:name)

        render json: { tags: tags.map { |tag| { id: tag.id, name: tag.name } } }
      end
    end
  end
end
