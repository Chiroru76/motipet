# frozen_string_literal: true

module Characters
  class PetResponseBuilder
    attr_reader :character, :growth_result, :event_context

    def initialize(character:, growth_result: {}, event_context: {})
      @character = character
      @growth_result = growth_result
      @event_context = event_context
    end

    def build
      {
        comment: generate_comment,
        appearance: fetch_appearance
      }
    end

    def generate_comment
      return nil if growth_result[:evolved] || growth_result[:hatched]

      event = determine_event
      return nil unless event

      PetComments::Generator.for(
        event,
        user: character.user,
        context: event_context
      )
    end

    private

    def determine_event
      if growth_result[:leveled_up]
        :level_up
      elsif event_context[:feed]
        :feed
      elsif event_context[:task_completed]
        :task_completed
      elsif event_context[:task_logged]
        :task_logged
      end
    end

    def fetch_appearance
      return nil unless character&.character_kind

      CharacterAppearance.find_by(
        character_kind: character.character_kind,
        pose: :idle
      )
    end
  end
end
