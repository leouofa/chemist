# frozen_string_literal: true

module Api
  module V1
    class FunctionalGroupsController < BaseController
      before_action :set_functional_group, only: %i[show update destroy neighbors generate_embedding]

      def index
        scope = FunctionalGroup.includes(molecule: :chemical_class)
        scope = scope.where(molecule_id: params[:molecule_id]) if params[:molecule_id].present?
        if params[:chemical_class_id].present?
          scope = scope.joins(:molecule).where(molecules: { chemical_class_id: params[:chemical_class_id] })
        end

        if params[:theme].present?
          scope = scope.where("EXISTS (SELECT 1 FROM jsonb_array_elements_text(functional_groups.themes) elem WHERE elem ILIKE ?)", "%#{params[:theme]}%")
        end

        if params[:q].present?
          scope = scope.joins(:molecule).where("functional_groups.name ILIKE :q OR functional_groups.description ILIKE :q OR molecules.name ILIKE :q", q: "%#{params[:q]}%")
        end

        if params.key?(:embedded)
          scope = boolean_param(:embedded) ? scope.where.not(embedding: nil) : scope.where(embedding: nil)
        end

        records, meta = paginate(scope.order("functional_groups.name ASC"))

        include_embedding = boolean_param(:include_embedding, default: false)
        data = records.map do |b|
          Serializer.functional_group(b, include_embedding: include_embedding, include_molecule: true)
        end

        render_success(data, meta: meta)
      end

      def search
        query = params[:q].to_s.strip
        return render_error(code: "blank_query", message: "Query parameter 'q' must not be blank") if query.blank?

        mode = params[:mode].presence || "auto"
        limit = (params[:limit].presence || 20).to_i.clamp(1, 100)

        scope = FunctionalGroup.includes(molecule: :chemical_class)
        scope = scope.where(molecule_id: params[:molecule_id]) if params[:molecule_id].present?
        if params[:chemical_class_id].present?
          scope = scope.joins(:molecule).where(molecules: { chemical_class_id: params[:chemical_class_id] })
        end

        if (mode == "semantic" || mode == "auto") && scope.where.not(embedding: nil).exists?
          begin
            embedding_res = Llm::EmbeddingGenerator.call(query)
            query_vector = embedding_res[:vector]

            neighbors = scope.where.not(embedding: nil)
                             .nearest_neighbors(:embedding, query_vector, distance: "cosine")
                             .limit(limit)

            results = neighbors.map do |functional_group|
              dist = functional_group.try(:neighbor_distance)
              Serializer.functional_group(functional_group, neighbor_distance: dist)
            end

            return render_success(results, meta: { mode: "semantic", query: query, count: results.size })
          rescue StandardError => e
            raise e if mode == "semantic"
          end
        end

        keyword_matches = scope.joins(:molecule)
                               .where("functional_groups.name ILIKE :q OR functional_groups.description ILIKE :q OR molecules.name ILIKE :q", q: "%#{query}%")
                               .limit(limit)

        results = keyword_matches.map { |b| Serializer.functional_group(b) }
        render_success(results, meta: { mode: "keyword", query: query, count: results.size })
      end

      def show
        render_success(
          Serializer.functional_group(@functional_group, include_embedding: boolean_param(:include_embedding, default: false), include_molecule: true)
        )
      end

      def create
        molecule = Molecule.find(params.require(:functional_group).require(:molecule_id))
        functional_group = molecule.functional_groups.create!(functional_group_params)
        render_success(Serializer.functional_group(functional_group), status: :created)
      end

      def update
        @functional_group.update!(functional_group_params)
        render_success(Serializer.functional_group(@functional_group))
      end

      def destroy
        @functional_group.destroy!
        render_success({ id: @functional_group.id, molecule_id: @functional_group.molecule_id, deleted: true })
      end

      def neighbors
        unless @functional_group.embedded?
          return render_error(code: "not_embedded", message: "Functional group does not have an embedding yet")
        end

        limit = (params[:limit].presence || 10).to_i.clamp(1, 100)
        scope = FunctionalGroup.includes(molecule: :chemical_class).where.not(id: @functional_group.id)
        scope = scope.where(molecule_id: params[:molecule_id]) if params[:molecule_id].present?
        if params[:chemical_class_id].present?
          scope = scope.joins(:molecule).where(molecules: { chemical_class_id: params[:chemical_class_id] })
        end

        neighbors = scope.nearest_neighbors(:embedding, @functional_group.embedding, distance: "cosine").limit(limit)
        results = neighbors.map do |neighbor|
          Serializer.functional_group(neighbor, neighbor_distance: neighbor.try(:neighbor_distance))
        end

        render_success(results, meta: { functional_group_id: @functional_group.id, count: results.size })
      end

      def generate_embedding
        if sync_requested?
          @functional_group.generate_embedding!
          render_success(Serializer.functional_group(@functional_group, include_embedding: boolean_param(:include_embedding, default: false)))
        else
          job = GenerateEmbeddingJob.perform_later("FunctionalGroup", @functional_group.id)
          render_success({ job_id: job.job_id, status: "queued", functional_group_id: @functional_group.id }, status: :accepted)
        end
      end

      def populate
        molecule_id = params[:molecule_id].presence
        if sync_requested?
          result = PopulateFunctionalGroupsJob.new.perform(molecule_id: molecule_id)
          render_success({ message: "Functional groups populated", result: result })
        else
          job = PopulateFunctionalGroupsJob.perform_later(molecule_id: molecule_id)
          render_success({ job_id: job.job_id, status: "queued", molecule_id: molecule_id }, status: :accepted)
        end
      end

      def upsert_batch
        molecule = Molecule.find(params.require(:molecule_id))
        entries = params.require(:functional_groups).map do |entry|
          entry.permit(:name, :description, themes: []).to_h
        end
        upserted = FunctionalGroup.upsert_batch!(molecule, entries)
        render_success(
          upserted.map { |b| Serializer.functional_group(b) },
          meta: { molecule_id: molecule.id, count: upserted.size }
        )
      end

      private

      def set_functional_group
        @functional_group = FunctionalGroup.includes(molecule: :chemical_class).find(params[:id])
      end

      def functional_group_params
        p = params.require(:functional_group).permit(:molecule_id, :name, :description, themes: [])
        p[:themes] = FunctionalGroup.normalize_themes(p[:themes]) if p.key?(:themes)
        p
      end
    end
  end
end
