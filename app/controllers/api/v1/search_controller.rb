# frozen_string_literal: true

module Api
  module V1
    class SearchController < BaseController
      def index
        query = params[:q].to_s.strip
        return render_error(code: "blank_query", message: "Query parameter 'q' must not be blank") if query.blank?

        target_type = params[:target_type].to_s.downcase.presence || "all"
        mode = params[:mode].presence || "auto"
        limit = (params[:limit].presence || 20).to_i.clamp(1, 100)

        molecules_scope = Molecule.includes(:chemical_class)
        functional_groups_scope = FunctionalGroup.includes(molecule: :chemical_class)

        if (mode == "semantic" || mode == "auto") && (molecules_scope.where.not(embedding: nil).exists? || functional_groups_scope.where.not(embedding: nil).exists?)
          begin
            embedding_res = Llm::EmbeddingGenerator.call(query)
            query_vector = embedding_res[:vector]

            molecule_results = []
            if %w[all molecule molecules].include?(target_type)
              molecule_results = molecules_scope.where.not(embedding: nil)
                                               .nearest_neighbors(:embedding, query_vector, distance: "cosine")
                                               .limit(limit)
                                               .map do |mol|
                                                 {
                                                   type: "Molecule",
                                                   score: 1.0 - mol.try(:neighbor_distance).to_f,
                                                   data: Serializer.molecule(mol, neighbor_distance: mol.try(:neighbor_distance))
                                                 }
                                               end
            end

            functional_group_results = []
            if %w[all functional_group functional_groups].include?(target_type)
              functional_group_results = functional_groups_scope.where.not(embedding: nil)
                                                               .nearest_neighbors(:embedding, query_vector, distance: "cosine")
                                                               .limit(limit)
                                                               .map do |fg|
                                                                 {
                                                                   type: "FunctionalGroup",
                                                                   score: 1.0 - fg.try(:neighbor_distance).to_f,
                                                                   data: Serializer.functional_group(fg, neighbor_distance: fg.try(:neighbor_distance))
                                                                 }
                                                               end
            end

            combined = (molecule_results + functional_group_results).sort_by { |item| -item[:score] }.take(limit)
            return render_success(combined, meta: { mode: "semantic", query: query, count: combined.size })
          rescue StandardError => e
            raise e if mode == "semantic"
          end
        end

        # Keyword fallback
        molecule_kw = []
        if %w[all molecule molecules].include?(target_type)
          molecule_kw = molecules_scope.where("molecules.name ILIKE :q OR molecules.description ILIKE :q", q: "%#{query}%")
                                       .limit(limit)
                                       .map { |m| { type: "Molecule", data: Serializer.molecule(m) } }
        end

        functional_group_kw = []
        if %w[all functional_group functional_groups].include?(target_type)
          functional_group_kw = functional_groups_scope.joins(:molecule)
                                                       .where("functional_groups.name ILIKE :q OR functional_groups.description ILIKE :q OR molecules.name ILIKE :q", q: "%#{query}%")
                                                       .limit(limit)
                                                       .map { |fg| { type: "FunctionalGroup", data: Serializer.functional_group(fg) } }
        end

        combined = (molecule_kw + functional_group_kw).take(limit)
        render_success(combined, meta: { mode: "keyword", query: query, count: combined.size })
      end
    end
  end
end
