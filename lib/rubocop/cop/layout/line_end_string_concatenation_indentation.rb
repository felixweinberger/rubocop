# frozen_string_literal: true

module RuboCop
  module Cop
    module Layout
      # This cop checks the indentation of the next line after a line that ends with a string
      # literal and a backslash.
      #
      # If `EnforcedStyle: aligned` is set, the concatenated string parts shall be aligned with the
      # first part. There are some exceptions, such as implicit return values, where the
      # concatenated string parts shall be indented regardless of `EnforcedStyle` configuration.
      #
      # If `EnforcedStyle: indented` is set, it's the second line that shall be indented one step
      # more than the first line. Lines 3 and forward shall be aligned with line 2. Here too there
      # are exceptions. Values in a hash literal are always aligned.
      #
      # @example
      #   # bad
      #   def some_method
      #     'x' \
      #     'y' \
      #     'z'
      #   end
      #
      #   my_hash = {
      #     first: 'a message' \
      #       'in two parts'
      #   }
      #
      #   # good
      #   def some_method
      #     'x' \
      #       'y' \
      #       'z'
      #   end
      #
      #   my_hash = {
      #     first: 'a message' \
      #            'in two parts'
      #   }
      #
      # @example EnforcedStyle: aligned (default)
      #   # bad
      #   puts 'x' \
      #     'y'
      #
      #   # good
      #   puts 'x' \
      #        'y'
      #
      # @example EnforcedStyle: indented
      #   # bad
      #   result = 'x' \
      #            'y'
      #
      #   # good
      #   result = 'x' \
      #     'y'
      #
      class LineEndStringConcatenationIndentation < Base
        include ConfigurableEnforcedStyle
        include Alignment
        extend AutoCorrector

        MSG_ALIGN = 'Align parts of a string concatenated with backslash.'
        MSG_INDENT = 'Indent the first part of a string concatenated with backslash.'
        PARENT_TYPES_FOR_INDENTED = [nil, :block, :begin, :def, :defs, :if].freeze

        def on_dstr(node)
          return unless strings_concatenated_with_backslash?(node)

          children = node.children
          if style == :aligned && !always_indented?(node) || always_aligned?(node)
            check_aligned(children, 1)
          else
            check_indented(children)
            check_aligned(children, 2)
          end
        end

        def autocorrect(corrector, node)
          AlignmentCorrector.correct(corrector, processed_source, node, @column_delta)
        end

        private

        def strings_concatenated_with_backslash?(dstr_node)
          !dstr_node.heredoc? &&
            !single_string_literal?(dstr_node) &&
            dstr_node.children.length > 1 &&
            dstr_node.children.all? { |c| c.str_type? || c.dstr_type? }
        end

        def single_string_literal?(dstr_node)
          dstr_node.loc.respond_to?(:begin) && dstr_node.loc.begin
        end

        def always_indented?(dstr_node)
          PARENT_TYPES_FOR_INDENTED.include?(dstr_node.parent&.type)
        end

        def always_aligned?(dstr_node)
          dstr_node.parent&.pair_type?
        end

        def check_aligned(children, start_index)
          base_column = children[start_index - 1].loc.column
          children[start_index..-1].each do |child|
            @column_delta = base_column - child.loc.column
            add_offense_and_correction(child, MSG_ALIGN) if @column_delta != 0
            base_column = child.loc.column
          end
        end

        def check_indented(children)
          base_column = children[0].source_range.source_line =~ /\S/
          @column_delta = base_column + configured_indentation_width - children[1].loc.column
          add_offense_and_correction(children[1], MSG_INDENT) if @column_delta != 0
        end

        def add_offense_and_correction(node, message)
          add_offense(node, message: message) { |corrector| autocorrect(corrector, node) }
        end
      end
    end
  end
end
