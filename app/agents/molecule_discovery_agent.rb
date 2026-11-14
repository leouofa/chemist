# frozen_string_literal: true

class MoleculeDiscoveryAgent < ApplicationAgent
  inputs :chemical_class_name, :chemical_class_description, :existing_names

  instructions do
    existing = Array(existing_names).compact_blank
    existing_clause =
      if existing.any?
        "Existing molecule names already in our database for this chemical class: #{existing.join(', ')}. " \
          "Reuse these exact names when referring to the same molecules so records update cleanly without duplicates, " \
          "and include any missing notable molecules as well."
      else
        "Use clear, canonical IUPAC or widely accepted common chemical names (e.g., 'Quinine', 'Morphine', 'Aspirin', 'Ferrocene', 'Caffeine', 'Benzene', 'Cisplatin', 'Penicillin G', 'Cholesterol')."
      end

    context_clause = chemical_class_description.present? ? "Chemical class context: #{chemical_class_description}" : ""

    <<~INSTRUCTIONS.squish
      You are an expert medicinal, organic, and materials chemist.
      Identify major and notable molecules, compounds, natural products, drugs, reagents, or organometallic complexes belonging to or associated with #{chemical_class_name}.
      #{context_clause}
      For each molecule or compound, provide:
      1. Its canonical common or systematic IUPAC name.
      2. A concise, informative description covering its molecular scaffold/formula, key bonding motifs, stereochemistry, physicochemical properties (such as lipophilicity, acid-base behavior, or redox potential), and prominent biological or synthetic applications.
      3. A JSON array of 2 to 6 concise thematic tags as lowercase strings (e.g., ["quinolizidine core", "nmda antagonist", "tertiary amine", "plant secondary metabolite"]).
      #{existing_clause}
      Respond ONLY with valid JSON matching this exact structure (no markdown fences or commentary):
      {"molecules":[{"name":"Quinine","description":"Cinchona alkaloid featuring a quinoline core linked via a chiral carbinol to a quinuclidine ring, historically vital as an antimalarial and chiral organocatalyst.","themes":["cinchona alkaloid","quinoline core","quinuclidine ring","antimalarial","chiral catalyst"]}]}
    INSTRUCTIONS
  end
end
