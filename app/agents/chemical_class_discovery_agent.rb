# frozen_string_literal: true

class ChemicalClassDiscoveryAgent < ApplicationAgent
  inputs :existing_names

  instructions do
    existing = Array(existing_names).compact_blank
    existing_clause =
      if existing.any?
        "Existing chemical class names already in our database: #{existing.join(', ')}. " \
          "Reuse these exact names when referring to the same chemical classes so records update cleanly without duplicates, " \
          "and include any missing major chemical classes as well."
      else
        "Include major, widely recognized chemical classes across organic, biochemical/medicinal, inorganic, organometallic, and polymeric/materials chemistry " \
          "(e.g., 'Alkaloids', 'Carboxylic Acids & Esters', 'Aromatic Hydrocarbons', 'Amino Acids & Peptides', 'Terpenoids & Steroids', 'Transition Metal Coordination Complexes', 'Organophosphorus Compounds', 'Beta-Lactam Antibiotics', 'Crown Ethers & Macrocycles', 'Conductive Polymers', 'Flavonoids & Polyphenols', 'Per- and Polyfluoroalkyl Substances (PFAS)')."
      end

    <<~INSTRUCTIONS.squish
      You are an expert chemist, chemoinformatician, and molecular taxonomist.
      Identify major chemical classes, compound families, and molecular categories across the chemical sciences.
      For each chemical class, provide its canonical name and a concise, high-signal description covering its structural hallmarks, characteristic bonding/scaffolds, primary reactivity modes, and biological or industrial relevance.
      #{existing_clause}
      Respond ONLY with valid JSON matching this exact structure (no markdown fences or commentary):
      {"chemical_classes":[{"name":"Alkaloids","description":"Naturally occurring basic organic compounds containing predominantly heterocyclic nitrogen atoms, exhibiting diverse pharmacodynamic activities and complex stereochemical polycyclic frameworks."}]}
    INSTRUCTIONS
  end
end
