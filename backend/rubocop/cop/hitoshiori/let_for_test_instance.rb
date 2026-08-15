# frozen_string_literal: true

module RuboCop
  module Cop
    module Hitoshiori
      # RSpecのexample内でテスト用インスタンスを直接生成することを禁止する。
      # 生成順を制御したい場合も、遅延評価のletをexample内で呼び出す。
      class LetForTestInstance < Base
        MSG = "テスト用インスタンスはexample内で直接生成せず、letまたはlet!で定義してください。"
        INSTANCE_CREATION_METHODS = %i[
          build
          build!
          build_list
          build_stubbed
          create
          create!
          create_list
          find_or_create_by
          find_or_create_by!
          new
        ].freeze
        EXAMPLE_METHODS = %i[
          example
          fexample
          fit
          fspecify
          it
          pending
          scenario
          skip
          specify
          xexample
          xit
          xscenario
          xspecify
        ].freeze

        def on_send(node)
          return unless INSTANCE_CREATION_METHODS.include?(node.method_name)
          return unless inside_example?(node)

          add_offense(node.loc.selector)
        end

        private

        def inside_example?(node)
          node.each_ancestor(:block).any? do |block|
            send_node = block.send_node
            send_node.receiver.nil? && EXAMPLE_METHODS.include?(send_node.method_name)
          end
        end
      end
    end
  end
end
