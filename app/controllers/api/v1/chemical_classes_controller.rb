# frozen_string_literal: true

module Api
  module V1
    class ChemicalClassesController < BaseController
      before_action :set_chemical_class, only: %i[show update destroy populate_molecules]

      def index
        scope = ChemicalClass.all
        scope = scope.where("name ILIKE :q OR description ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?

        records, meta = paginate(scope.order("name ASC"))
        include_molecules = boolean_param(:include_molecules, default: false)

        data = records.map do |c|
          Serializer.chemical_class(c, include_molecules: include_molecules)
        end

        render_success(data, meta: meta)
      end

      def show
        render_success(
          Serializer.chemical_class(@chemical_class, include_molecules: boolean_param(:include_molecules, default: true))
        )
      end

      def create
        chemical_class = ChemicalClass.create!(chemical_class_params)
        render_success(Serializer.chemical_class(chemical_class), status: :created)
      end

      def update
        @chemical_class.update!(chemical_class_params)
        render_success(Serializer.chemical_class(@chemical_class))
      end

      def destroy
        @chemical_class.destroy!
        render_success({ id: @chemical_class.id, name: @chemical_class.name, deleted: true })
      end

      def populate_molecules
        if sync_requested?
          result = PopulateMoleculesJob.new.perform(chemical_class_id: @chemical_class.id)
          render_success({ message: "Star systems populated for #{@chemical_class.name}", result: result })
        else
          job = PopulateMoleculesJob.perform_later(chemical_class_id: @chemical_class.id)
          render_success({ job_id: job.job_id, status: "queued", chemical_class_id: @chemical_class.id }, status: :accepted)
        end
      end

      def populate
        if sync_requested?
          result = PopulateChemicalClassesJob.new.perform
          render_success({ message: "Chemical classes populated", result: result })
        else
          job = PopulateChemicalClassesJob.perform_later
          render_success({ job_id: job.job_id, status: "queued" }, status: :accepted)
        end
      end

      def upsert_batch
        entries = params.require(:chemical_classes).map do |entry|
          entry.permit(:name, :description).to_h
        end
        upserted = ChemicalClass.upsert_batch!(entries)
        render_success(
          upserted.map { |c| Serializer.chemical_class(c) },
          meta: { count: upserted.size }
        )
      end

      private

      def set_chemical_class
        @chemical_class = ChemicalClass.find(params[:id])
      end

      def chemical_class_params
        params.require(:chemical_class).permit(:name, :description)
      end
    end
  end
end
