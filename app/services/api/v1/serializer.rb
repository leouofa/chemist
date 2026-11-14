# frozen_string_literal: true

module Api
  module V1
    class Serializer
      class << self
        def chemical_class(record, include_molecules: false, molecules_count: nil)
          data = {
            id: record.id,
            name: record.name,
            description: record.description,
            created_at: record.created_at&.iso8601,
            updated_at: record.updated_at&.iso8601,
            molecules_count: molecules_count || record.molecules.size
          }

          if include_molecules && record.association(:molecules).loaded?
            data[:molecules] = record.molecules.map { |m| molecule(m, include_chemical_class: false) }
          elsif include_molecules
            data[:molecules] = record.molecules.ordered.map { |m| molecule(m, include_chemical_class: false) }
          end

          data
        end

        def molecule(record, include_embedding: false, include_functional_groups: false, include_chemical_class: true, neighbor_distance: nil)
          data = {
            id: record.id,
            chemical_class_id: record.chemical_class_id,
            name: record.name,
            description: record.description,
            themes: record.themes || [],
            functional_groups_count: record.functional_groups.size,
            embedded: record.embedded?,
            embedding_model: record.embedding_model,
            embedded_at: record.embedded_at&.iso8601,
            embedding_dimensions: record.embedding_dimensions,
            created_at: record.created_at&.iso8601,
            updated_at: record.updated_at&.iso8601
          }

          data[:neighbor_distance] = neighbor_distance.to_f if neighbor_distance.present?

          if include_chemical_class && record.association(:chemical_class).loaded?
            data[:chemical_class] = record.chemical_class ? { id: record.chemical_class.id, name: record.chemical_class.name } : nil
          elsif include_chemical_class && record.chemical_class_id.present?
            cc = record.chemical_class
            data[:chemical_class] = cc ? { id: cc.id, name: cc.name } : nil
          end

          if include_functional_groups
            data[:functional_groups] = record.functional_groups.ordered.map { |fg_rec| functional_group(fg_rec, include_molecule: false) }
          end

          if include_embedding
            data[:embedding] = record.embedding&.to_a
          end

          data
        end

        def functional_group(record, include_embedding: false, include_molecule: true, neighbor_distance: nil)
          data = {
            id: record.id,
            molecule_id: record.molecule_id,
            name: record.name,
            description: record.description,
            themes: record.themes || [],
            embedded: record.embedded?,
            embedding_model: record.embedding_model,
            embedded_at: record.embedded_at&.iso8601,
            embedding_dimensions: record.embedding_dimensions,
            created_at: record.created_at&.iso8601,
            updated_at: record.updated_at&.iso8601
          }

          data[:neighbor_distance] = neighbor_distance.to_f if neighbor_distance.present?

          if include_molecule
            mol = record.molecule
            if mol
              cc = mol.chemical_class
              data[:molecule] = {
                id: mol.id,
                name: mol.name,
                chemical_class_id: mol.chemical_class_id,
                chemical_class_name: cc&.name
              }
            end
          end

          if include_embedding
            data[:embedding] = record.embedding&.to_a
          end

          data
        end

        def live_cluster_result(result, unembedded_count: 0)
          {
            target_type: result.target_class.name,
            level: result.level,
            distance_threshold: result.distance_threshold,
            full_coverage: result.full_coverage?,
            total_embedded_count: result.total_embedded_count,
            unembedded_count: unembedded_count,
            clusters_count: result.multi_clusters_count,
            singletons_count: result.singletons_count,
            largest_cluster_size: result.largest_cluster_size,
            generated_at: result.generated_at&.iso8601,
            clusters: result.clusters.map do |c|
              {
                id: c.id,
                name: c.name,
                shared_themes: c.shared_themes,
                size: c.size,
                chemical_classes: c.chemical_classes,
                members: c.records.map do |rec|
                  rec.is_a?(Molecule) ? molecule(rec, include_chemical_class: true) : functional_group(rec, include_molecule: true)
                end
              }
            end,
            singletons: result.singletons.map do |rec|
              rec.is_a?(Molecule) ? molecule(rec, include_chemical_class: true) : functional_group(rec, include_molecule: true)
            end
          }
        end

        def cluster_snapshot(snapshot, include_groups: false, include_members: false, include_reports: false)
          data = {
            id: snapshot.id,
            target_type: snapshot.target_type,
            level: snapshot.level,
            distance_threshold: snapshot.distance_threshold,
            title: snapshot.title,
            clusters_count: snapshot.clusters_count,
            items_count: snapshot.items_count,
            created_at: snapshot.created_at&.iso8601,
            updated_at: snapshot.updated_at&.iso8601
          }

          if include_groups
            groups_scope = snapshot.cluster_groups.by_size
            groups_scope = groups_scope.includes(cluster_memberships: eager_associations_for(snapshot.target_type)) if include_members
            data[:groups] = groups_scope.map { |g| cluster_group(g, include_members: include_members) }
          end

          if include_reports
            data[:reports] = snapshot.cluster_reports.ordered.map { |r| cluster_report(r) }
          end

          data
        end

        def cluster_group(group, include_members: true)
          data = {
            id: group.id,
            cluster_snapshot_id: group.cluster_snapshot_id,
            name: group.name,
            shared_themes: group.shared_themes || [],
            size: group.size,
            created_at: group.created_at&.iso8601,
            updated_at: group.updated_at&.iso8601
          }

          if include_members
            memberships = group.cluster_memberships.to_a
            data[:members] = memberships.filter_map do |m|
              rec = m.record
              next nil unless rec

              if rec.is_a?(Molecule)
                molecule(rec, include_chemical_class: true)
              elsif rec.is_a?(FunctionalGroup)
                functional_group(rec, include_molecule: true)
              else
                { id: rec.id, type: rec.class.name }
              end
            end
          end

          data
        end

        def cluster_membership(membership)
          {
            id: membership.id,
            cluster_group_id: membership.cluster_group_id,
            record_type: membership.record_type,
            record_id: membership.record_id,
            created_at: membership.created_at&.iso8601,
            record: if membership.record.is_a?(Molecule)
                      molecule(membership.record, include_chemical_class: true)
                    elsif membership.record.is_a?(FunctionalGroup)
                      functional_group(membership.record, include_molecule: true)
                    else
                      nil
                    end
          }
        end

        def cluster_report(report, include_summaries: false, include_sub_reports: false)
          data = {
            id: report.id,
            cluster_snapshot_id: report.cluster_snapshot_id,
            title: report.title,
            prompt: report.prompt,
            status: report.status,
            phase: report.phase,
            phase_description: report.phase_description,
            progress_percentage: report.progress_percentage,
            is_detailed: report.detailed?,
            batch_size: report.batch_size,
            parent_report_id: report.parent_report_id,
            detailed_report_ids: report.detailed_reports.pluck(:id),
            summarized_clusters_count: report.summarized_clusters_count,
            total_clusters_count: report.total_clusters_count,
            aggregated_batches_count: report.aggregated_batches_count,
            total_batches_count: report.total_batches_count,
            content: report.content,
            error_message: report.error_message,
            completed_at: report.completed_at&.iso8601,
            created_at: report.created_at&.iso8601,
            updated_at: report.updated_at&.iso8601
          }

          if include_summaries
            data[:summaries] = report.cluster_report_summaries.ordered.map { |s| cluster_report_summary(s) }
          end

          if include_sub_reports
            data[:sub_reports] = report.cluster_sub_reports.ordered.map { |sr| cluster_sub_report(sr) }
          end

          data
        end

        def cluster_report_summary(summary)
          {
            id: summary.id,
            cluster_report_id: summary.cluster_report_id,
            cluster_group_id: summary.cluster_group_id,
            cluster_group_name: summary.cluster_group&.name,
            position: summary.position,
            content: summary.content,
            created_at: summary.created_at&.iso8601,
            updated_at: summary.updated_at&.iso8601
          }
        end

        def cluster_sub_report(sub_report)
          {
            id: sub_report.id,
            cluster_report_id: sub_report.cluster_report_id,
            batch_index: sub_report.batch_index,
            cluster_group_ids: sub_report.cluster_group_ids || [],
            content: sub_report.content,
            created_at: sub_report.created_at&.iso8601,
            updated_at: sub_report.updated_at&.iso8601
          }
        end

        def settings_payload
          {
            molecule_stats: GenerateAllEmbeddingsJob.stats_for(Molecule),
            functional_group_stats: GenerateAllEmbeddingsJob.stats_for(FunctionalGroup),
            embedding_config: {
              model: Llm::EmbeddingGenerator.configured_model,
              api_base: Llm::EmbeddingGenerator.configured_api_base,
              dimensions: Llm::EmbeddingGenerator::DIMENSIONS
            },
            llm_config: {
              model: ENV["OLLAMA_MODEL"],
              api_base: ENV["OLLAMA_API_BASE"],
              context_window: Llm::ModelRegistry.current_context_window,
              digest_char_budget: Llm::ModelRegistry.digest_char_budget,
              presets: Llm::ModelRegistry::CONTEXT_WINDOW_PRESETS
            }
          }
        end

        private

        def eager_associations_for(target_type)
          case target_type
          when "Molecule"
            { record: :chemical_class }
          when "FunctionalGroup"
            { record: { molecule: :chemical_class } }
          else
            :record
          end
        end
      end
    end
  end
end
