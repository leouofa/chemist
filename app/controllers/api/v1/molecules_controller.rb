# frozen_string_literal: true

module Api
  module V1
    class MoleculesController < BaseController
      before_action :set_molecule, only: %i[show update destroy neighbors generate_embedding populate_functional_groups]

      def index
        scope = Molecule.includes(:chemical_class)
        scope = scope.where(chemical_class_id: params[:chemical_class_id]) if params[:chemical_class_id].present?
        if params[:chemical_class].present?
          scope = scope.joins(:chemical_class).where("chemical_classs.name ILIKE ?", "%#{params[:chemical_class]}%")
        end

        if params[:theme].present?
          scope = scope.where("EXISTS (SELECT 1 FROM jsonb_array_elements_text(molecules.themes) elem WHERE elem ILIKE ?)", "%#{params[:theme]}%")
        end

        if params[:q].present?
          scope = scope.where("molecules.name ILIKE :q OR molecules.description ILIKE :q", q: "%#{params[:q]}%")
        end

        if params.key?(:embedded)
          scope = boolean_param(:embedded) ? scope.where.not(embedding: nil) : scope.where(embedding: nil)
        end

        records, meta = paginate(scope.order("molecules.name ASC"))

        include_embedding = boolean_param(:include_embedding, default: false)
        include_functional_groups = boolean_param(:include_functional_groups, default: false)

        data = records.map do |s|
          Serializer.molecule(s, include_embedding: include_embedding, include_functional_groups: include_functional_groups)
        end

        render_success(data, meta: meta)
      end

      def search
        query = params[:q].to_s.strip
        return render_error(code: "blank_query", message: "Query parameter 'q' must not be blank") if query.blank?

        mode = params[:mode].presence || "auto"
        limit = (params[:limit].presence || 20).to_i.clamp(1, 100)

        scope = Molecule.includes(:chemical_class)
        scope = scope.where(chemical_class_id: params[:chemical_class_id]) if params[:chemical_class_id].present?

        if (mode == "semantic" || mode == "auto") && scope.where.not(embedding: nil).exists?
          begin
            embedding_res = Llm::EmbeddingGenerator.call(query)
            query_vector = embedding_res[:vector]

            neighbors = scope.where.not(embedding: nil)
                             .nearest_neighbors(:embedding, query_vector, distance: "cosine")
                             .limit(limit)

            results = neighbors.map do |molecule|
              dist = molecule.try(:neighbor_distance)
              Serializer.molecule(molecule, neighbor_distance: dist)
            end

            return render_success(results, meta: { mode: "semantic", query: query, count: results.size })
          rescue StandardError => e
            raise e if mode == "semantic"
          end
        end

        keyword_matches = scope.where("molecules.name ILIKE :q OR molecules.description ILIKE :q", q: "%#{query}%")
                               .limit(limit)

        results = keyword_matches.map { |molecule| Serializer.molecule(molecule) }
        render_success(results, meta: { mode: "keyword", query: query, count: results.size })
      end

      def show
        render_success(
          Serializer.molecule(
            @molecule,
            include_embedding: boolean_param(:include_embedding, default: false),
            include_functional_groups: boolean_param(:include_functional_groups, default: true)
          )
        )
      end

      def create
        molecule = Molecule.create!(molecule_params)
        render_success(Serializer.molecule(molecule), status: :created)
      end

      def update
        @molecule.update!(molecule_params)
        render_success(Serializer.molecule(@molecule))
      end

      def destroy
        @molecule.destroy!
        render_success({ id: @molecule.id, name: @molecule.name, deleted: true })
      end

      def neighbors
        unless @molecule.embedded?
          return render_error(code: "not_embedded", message: "Star system '#{@molecule.name}' does not have an embedding yet")
        end

        limit = (params[:limit].presence || 10).to_i.clamp(1, 100)
        scope = Molecule.includes(:chemical_class).where.not(id: @molecule.id)
        scope = scope.where(chemical_class_id: params[:chemical_class_id]) if params[:chemical_class_id].present?

        neighbors = scope.nearest_neighbors(:embedding, @molecule.embedding, distance: "cosine").limit(limit)
        results = neighbors.map do |neighbor|
          Serializer.molecule(neighbor, neighbor_distance: neighbor.try(:neighbor_distance))
        end

        render_success(results, meta: { molecule_id: @molecule.id, count: results.size })
      end

      def generate_embedding
        if sync_requested?
          @molecule.generate_embedding!
          render_success(Serializer.molecule(@molecule, include_embedding: boolean_param(:include_embedding, default: false)))
        else
          job = GenerateEmbeddingJob.perform_later("Molecule", @molecule.id)
          render_success({ job_id: job.job_id, status: "queued", molecule_id: @molecule.id }, status: :accepted)
        end
      end

      def populate_functional_groups
        if sync_requested?
          result = PopulateFunctionalGroupsJob.new.perform(molecule_id: @molecule.id)
          render_success({ message: "Functional groups populated for #{@molecule.name}", result: result })
        else
          job = PopulateFunctionalGroupsJob.perform_later(molecule_id: @molecule.id)
          render_success({ job_id: job.job_id, status: "queued", molecule_id: @molecule.id }, status: :accepted)
        end
      end

      def populate
        chemical_class_id = params[:chemical_class_id].presence
        if sync_requested?
          result = PopulateMoleculesJob.new.perform(chemical_class_id: chemical_class_id)
          render_success({ message: "Molecules populated", result: result })
        else
          job = PopulateMoleculesJob.perform_later(chemical_class_id: chemical_class_id)
          render_success({ job_id: job.job_id, status: "queued", chemical_class_id: chemical_class_id }, status: :accepted)
        end
      end

      def upsert_batch
        chemical_class = ChemicalClass.find(params.require(:chemical_class_id))
        entries = params.require(:molecules).map do |entry|
          entry.permit(:name, :description, themes: []).to_h
        end
        upserted = Molecule.upsert_batch!(chemical_class, entries)
        render_success(
          upserted.map { |s| Serializer.molecule(s) },
          meta: { chemical_class_id: chemical_class.id, count: upserted.size }
        )
      end

      private

      def set_molecule
        @molecule = Molecule.includes(:chemical_class, :functional_groups).find(params[:id])
      end

      def molecule_params
        p = params.require(:molecule).permit(:chemical_class_id, :name, :description, themes: [])
        p[:themes] = Molecule.normalize_themes(p[:themes]) if p.key?(:themes)
        p
      end
    end
  end
end
