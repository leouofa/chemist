# frozen_string_literal: true

class FunctionalGroupDiscoveryAgent < ApplicationAgent
  inputs :molecule_name, :molecule_description, :molecule_themes, :chemical_class_name, :existing_names

  instructions do
    existing = Array(existing_names).compact_blank
    existing_clause =
      if existing.any?
        "Existing functional group / atomic site names already in our database for this molecule: #{existing.join(', ')}. " \
          "Reuse these exact names when referring to the same groups so records update cleanly without duplicates, " \
          "and include any missing key groups as well."
      else
        "Identify 6 to 10 major, chemically prominent, or reactive functional groups, pharmacophores, structural subunits, ring systems, coordination centers, or distinctive atomic environments in this molecule."
      end

    themes_list = Array(molecule_themes).compact_blank
    themes_clause = themes_list.any? ? "Molecule thematic tags: #{themes_list.join(', ')}." : ""
    desc_clause = molecule_description.present? ? "Molecule context: #{molecule_description}" : ""

    <<~INSTRUCTIONS.squish
      You are an expert structural chemist, spectroscopic analyst, and physical organic chemist.
      Identify 6 to 10 major, chemically significant, or reactive functional groups, structural moieties, rings, pharmacophoric elements, or distinct atomic sites in #{molecule_name} (#{chemical_class_name}).
      Ensure representation of primary reactive centers, hydrogen bond donors/acceptors, aromatic or aliphatic ring subunits, coordination centers, stereocenters, or ionizable functional groups.
      #{desc_clause}
      #{themes_clause}
      #{existing_clause}

      For each functional group or atomic environment, provide:
      1. Its canonical chemical name or motif designation (e.g., 'Quinoline Aromatic Ring', 'Quinuclidine Bridgehead Nitrogen', 'Secondary Carbinol Hydroxyl', 'Vinyl Olefinic Moiety').
      2. A concise, informative description covering its hybridization, local electronic distribution (inductive/mesomeric effects), pKa or acid/base status, steric profile, and role in reactivity, catalysis, or binding affinity.
      3. A JSON array of 2 to 6 concise thematic tags as lowercase strings (e.g., ["tertiary aliphatic amine", "bridgehead nitrogen", "hydrogen bond acceptor", "basic center"]).

      Respond ONLY with valid JSON matching this exact structure (no markdown fences or commentary):
      {"functional_groups":[{"name":"Quinuclidine Bridgehead Nitrogen","description":"Bicyclic tertiary amine with constrained pyramidal geometry, providing a localized lone pair that acts as a strong nucleophilic and basic center with high proton affinity.","themes":["tertiary amine","bridgehead center","hydrogen bond acceptor","basic center","nucleophilic motif"]}]}
    INSTRUCTIONS
  end
end
