# frozen_string_literal: true

module Api
  module V1
    class OpenapiSpec
      def self.generate
        {
          openapi: "3.1.0",
          info: {
            title: "Chemist Platform REST API",
            version: "1.0.0",
            description: "Full programmatic REST API for the Chemist comparative chemistry, molecular structure, and chemoinformatics research platform."
          },
          servers: [
            { url: "/api/v1", description: "Default v1 endpoint" }
          ],
          paths: {
            "/status" => {
              get: {
                summary: "Platform status, health, and entity statistics",
                operationId: "getPlatformStatus",
                responses: {
                  "200" => { description: "Current platform status and counts" }
                }
              }
            },
            "/openapi.json" => {
              get: {
                summary: "OpenAPI 3.1 specification for Chemist",
                operationId: "getOpenapiSpec",
                responses: {
                  "200" => { description: "OpenAPI schema document" }
                }
              }
            },
            "/search" => {
              get: {
                summary: "Cross-resource semantic or keyword search across Countries and Cities",
                operationId: "searchAll",
                parameters: [
                  { name: "q", in: "query", required: true, schema: { type: "string" } },
                  { name: "mode", in: "query", required: false, schema: { type: "string", enum: %w[semantic keyword auto], default: "auto" } },
                  { name: "target_type", in: "query", required: false, schema: { type: "string", enum: %w[all molecule functional_group], default: "all" } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 20 } }
                ],
                responses: {
                  "200" => { description: "Search results with similarity distances" }
                }
              }
            },
            "/chemical_classes" => {
              get: {
                summary: "List chemical_classes",
                operationId: "listChemicalClasses",
                parameters: [
                  { name: "q", in: "query", required: false, schema: { type: "string" } },
                  { name: "include_molecules", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 50 } },
                  { name: "offset", in: "query", required: false, schema: { type: "integer", default: 0 } }
                ],
                responses: { "200" => { description: "List of chemical_classes" } }
              },
              post: {
                summary: "Create a chemical_class",
                operationId: "createChemicalClass",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[name description],
                        properties: {
                          name: { type: "string" },
                          description: { type: "string" }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Created chemical_class" } }
              }
            },
            "/chemical_classes/{id}" => {
              get: {
                summary: "Get chemical_class details",
                operationId: "getChemicalClass",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_molecules", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "ChemicalClass details" } }
              },
              patch: {
                summary: "Update chemical_class",
                operationId: "updateChemicalClass",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        properties: {
                          name: { type: "string" },
                          description: { type: "string" }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Updated chemical_class" } }
              },
              delete: {
                summary: "Delete chemical_class",
                operationId: "deleteChemicalClass",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "ChemicalClass deleted" } }
              }
            },
            "/chemical_classes/upsert_batch" => {
              post: {
                summary: "Batch upsert chemical_classes",
                operationId: "batchUpsertChemicalClasses",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[chemical_classes],
                        properties: {
                          chemical_classes: {
                            type: "array",
                            items: {
                              type: "object",
                              required: %w[name description],
                              properties: {
                                name: { type: "string" },
                                description: { type: "string" }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Upserted chemical_classes" } }
              }
            },
            "/chemical_classes/populate" => {
              post: {
                summary: "Trigger LLM discovery of chemical_classes",
                operationId: "populateChemicalClasses",
                parameters: [
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Sync response" }, "202" => { description: "Async job queued" } }
              }
            },
            "/chemical_classes/{id}/populate_molecules" => {
              post: {
                summary: "Trigger LLM discovery of molecules for a single chemical_class",
                operationId: "populateChemicalClassCountries",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Sync response" }, "202" => { description: "Async job queued" } }
              }
            },
            "/molecules" => {
              get: {
                summary: "List/filter molecules",
                operationId: "listCountries",
                parameters: [
                  { name: "chemical_class_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "chemical_class", in: "query", required: false, schema: { type: "string" } },
                  { name: "theme", in: "query", required: false, schema: { type: "string" } },
                  { name: "q", in: "query", required: false, schema: { type: "string" } },
                  { name: "embedded", in: "query", required: false, schema: { type: "boolean" } },
                  { name: "include_embedding", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "include_functional_groups", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 50 } },
                  { name: "offset", in: "query", required: false, schema: { type: "integer", default: 0 } }
                ],
                responses: { "200" => { description: "List of molecules" } }
              },
              post: {
                summary: "Create a molecule",
                operationId: "createMolecule",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[chemical_class_id name description],
                        properties: {
                          chemical_class_id: { type: "integer" },
                          name: { type: "string" },
                          description: { type: "string" },
                          themes: { type: "array", items: { type: "string" } }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Created molecule" } }
              }
            },
            "/molecules/search" => {
              get: {
                summary: "Semantic or keyword search for molecules",
                operationId: "searchCountries",
                parameters: [
                  { name: "q", in: "query", required: true, schema: { type: "string" } },
                  { name: "mode", in: "query", required: false, schema: { type: "string", enum: %w[semantic keyword auto], default: "auto" } },
                  { name: "chemical_class_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 20 } }
                ],
                responses: { "200" => { description: "Molecule search results" } }
              }
            },
            "/molecules/{id}" => {
              get: {
                summary: "Get molecule details",
                operationId: "getMolecule",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_embedding", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "include_functional_groups", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Molecule details" } }
              },
              patch: {
                summary: "Update molecule",
                operationId: "updateMolecule",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        properties: {
                          name: { type: "string" },
                          description: { type: "string" },
                          themes: { type: "array", items: { type: "string" } },
                          chemical_class_id: { type: "integer" }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Updated molecule" } }
              },
              delete: {
                summary: "Delete molecule",
                operationId: "deleteMolecule",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Molecule deleted" } }
              }
            },
            "/molecules/{id}/neighbors" => {
              get: {
                summary: "Nearest-neighbor molecules by cosine distance",
                operationId: "getMoleculeNeighbors",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 10 } },
                  { name: "chemical_class_id", in: "query", required: false, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Nearest neighbors" } }
              }
            },
            "/molecules/{id}/generate_embedding" => {
              post: {
                summary: "Generate vector embedding for molecule",
                operationId: "generateMoleculeEmbedding",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Embedding generated" }, "202" => { description: "Job queued" } }
              }
            },
            "/molecules/{id}/populate_functional_groups" => {
              post: {
                summary: "Discover/populate functional_groups for a molecule via LLM",
                operationId: "populateMoleculeCities",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Cities created" }, "202" => { description: "Job queued" } }
              }
            },
            "/molecules/populate" => {
              post: {
                summary: "Trigger bulk LLM molecule discovery",
                operationId: "populateAllCountries",
                parameters: [
                  { name: "chemical_class_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Sync response" }, "202" => { description: "Job queued" } }
              }
            },
            "/molecules/upsert_batch" => {
              post: {
                summary: "Batch upsert molecules for a chemical_class",
                operationId: "batchUpsertCountries",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[chemical_class_id molecules],
                        properties: {
                          chemical_class_id: { type: "integer" },
                          molecules: {
                            type: "array",
                            items: {
                              type: "object",
                              required: %w[name description],
                              properties: {
                                name: { type: "string" },
                                description: { type: "string" },
                                themes: { type: "array", items: { type: "string" } }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Upserted molecules" } }
              }
            },
            "/functional_groups" => {
              get: {
                summary: "List/filter functional_groups",
                operationId: "listCities",
                parameters: [
                  { name: "molecule_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "chemical_class_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "theme", in: "query", required: false, schema: { type: "string" } },
                  { name: "q", in: "query", required: false, schema: { type: "string" } },
                  { name: "embedded", in: "query", required: false, schema: { type: "boolean" } },
                  { name: "include_embedding", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 50 } },
                  { name: "offset", in: "query", required: false, schema: { type: "integer", default: 0 } }
                ],
                responses: { "200" => { description: "List of functional_groups" } }
              },
              post: {
                summary: "Create a functional_group for a molecule",
                operationId: "createFunctionalGroup",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[molecule_id name description],
                        properties: {
                          molecule_id: { type: "integer" },
                          name: { type: "string" },
                          description: { type: "string" },
                          themes: { type: "array", items: { type: "string" } }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Created functional_group" } }
              }
            },
            "/functional_groups/search" => {
              get: {
                summary: "Semantic or keyword search for functional_groups",
                operationId: "searchCities",
                parameters: [
                  { name: "q", in: "query", required: true, schema: { type: "string" } },
                  { name: "mode", in: "query", required: false, schema: { type: "string", enum: %w[semantic keyword auto], default: "auto" } },
                  { name: "molecule_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "chemical_class_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 20 } }
                ],
                responses: { "200" => { description: "FunctionalGroup search results" } }
              }
            },
            "/functional_groups/{id}" => {
              get: {
                summary: "Get functional_group details",
                operationId: "getFunctionalGroup",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_embedding", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "FunctionalGroup details" } }
              },
              patch: {
                summary: "Update functional_group",
                operationId: "updateFunctionalGroup",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        properties: {
                          name: { type: "string" },
                          description: { type: "string" },
                          themes: { type: "array", items: { type: "string" } }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Updated functional_group" } }
              },
              delete: {
                summary: "Delete functional_group",
                operationId: "deleteFunctionalGroup",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "FunctionalGroup deleted" } }
              }
            },
            "/functional_groups/{id}/neighbors" => {
              get: {
                summary: "Nearest-neighbor functional_groups by cosine distance",
                operationId: "getFunctionalGroupNeighbors",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 10 } },
                  { name: "molecule_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "chemical_class_id", in: "query", required: false, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Nearest neighbors" } }
              }
            },
            "/functional_groups/{id}/generate_embedding" => {
              post: {
                summary: "Generate vector embedding for functional_group",
                operationId: "generateFunctionalGroupEmbedding",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Embedding generated" }, "202" => { description: "Job queued" } }
              }
            },
            "/functional_groups/populate" => {
              post: {
                summary: "Trigger bulk LLM functional_group discovery",
                operationId: "populateAllCities",
                parameters: [
                  { name: "molecule_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Sync response" }, "202" => { description: "Job queued" } }
              }
            },
            "/functional_groups/upsert_batch" => {
              post: {
                summary: "Batch upsert functional_groups for a molecule",
                operationId: "batchUpsertCities",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[molecule_id functional_groups],
                        properties: {
                          molecule_id: { type: "integer" },
                          functional_groups: {
                            type: "array",
                            items: {
                              type: "object",
                              required: %w[name description],
                              properties: {
                                name: { type: "string" },
                                description: { type: "string" },
                                themes: { type: "array", items: { type: "string" } }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Upserted functional_groups" } }
              }
            },
            "/clusters" => {
              get: {
                summary: "Compute or fetch live clusters",
                operationId: "getLiveClusters",
                parameters: [
                  { name: "target_type", in: "query", required: false, schema: { type: "string", enum: %w[Molecule FunctionalGroup], default: "Molecule" } },
                  { name: "level", in: "query", required: false, schema: { type: "integer", minimum: 1, maximum: 15, default: 5 } },
                  { name: "full_coverage", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "force", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Clustering result" } }
              }
            },
            "/clusters/snapshot" => {
              post: {
                summary: "Compute and save a cluster snapshot",
                operationId: "createSnapshotFromCluster",
                requestBody: {
                  required: false,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        properties: {
                          target_type: { type: "string", enum: %w[Molecule FunctionalGroup], default: "Molecule" },
                          level: { type: "integer", default: 5 },
                          full_coverage: { type: "boolean", default: false },
                          title: { type: "string" }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Persisted ClusterSnapshot" } }
              }
            },
            "/cluster_snapshots" => {
              get: {
                summary: "List cluster snapshots",
                operationId: "listClusterSnapshots",
                parameters: [
                  { name: "target_type", in: "query", required: false, schema: { type: "string", enum: %w[Molecule FunctionalGroup] } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 50 } },
                  { name: "offset", in: "query", required: false, schema: { type: "integer", default: 0 } }
                ],
                responses: { "200" => { description: "List of snapshots" } }
              },
              post: {
                summary: "Create and persist a snapshot",
                operationId: "createClusterSnapshot",
                requestBody: {
                  required: false,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        properties: {
                          target_type: { type: "string", enum: %w[Molecule FunctionalGroup], default: "Molecule" },
                          level: { type: "integer", default: 5 },
                          full_coverage: { type: "boolean", default: false },
                          title: { type: "string" }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Created snapshot" } }
              }
            },
            "/cluster_snapshots/{id}" => {
              get: {
                summary: "Get cluster snapshot details with groups",
                operationId: "getClusterSnapshot",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_groups", in: "query", required: false, schema: { type: "boolean", default: true } },
                  { name: "include_members", in: "query", required: false, schema: { type: "boolean", default: true } },
                  { name: "include_reports", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Snapshot details" } }
              },
              delete: {
                summary: "Delete cluster snapshot",
                operationId: "deleteClusterSnapshot",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Snapshot deleted" } }
              }
            },
            "/cluster_snapshots/{cluster_snapshot_id}/cluster_groups" => {
              get: {
                summary: "List cluster groups in a snapshot",
                operationId: "listSnapshotGroups",
                parameters: [
                  { name: "cluster_snapshot_id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_members", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "List of cluster groups" } }
              }
            },
            "/cluster_groups/{id}" => {
              get: {
                summary: "Get cluster group details with members",
                operationId: "getClusterGroup",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_members", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Cluster group details" } }
              }
            },
            "/cluster_reports" => {
              get: {
                summary: "List cluster reports",
                operationId: "listClusterReports",
                parameters: [
                  { name: "cluster_snapshot_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "target_type", in: "query", required: false, schema: { type: "string", enum: %w[Molecule FunctionalGroup] } },
                  { name: "status", in: "query", required: false, schema: { type: "string" } },
                  { name: "is_detailed", in: "query", required: false, schema: { type: "boolean" } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 50 } },
                  { name: "offset", in: "query", required: false, schema: { type: "integer", default: 0 } }
                ],
                responses: { "200" => { description: "List of cluster reports" } }
              },
              post: {
                summary: "Create a cluster synthesis report",
                operationId: "createClusterReport",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[cluster_snapshot_id],
                        properties: {
                          cluster_snapshot_id: { type: "integer" },
                          prompt: { type: "string" }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Created report" } }
              }
            },
            "/cluster_reports/{id}" => {
              get: {
                summary: "Get cluster report details",
                operationId: "getClusterReport",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_summaries", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "include_sub_reports", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Cluster report details" } }
              },
              delete: {
                summary: "Delete cluster report",
                operationId: "deleteClusterReport",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Report deleted" } }
              }
            },
            "/cluster_reports/{id}/deep_synthesis" => {
              post: {
                summary: "Create detailed 3-phase report from an existing report",
                operationId: "createDeepSynthesisReport",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                requestBody: {
                  required: false,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        properties: {
                          batch_size: { type: "integer", minimum: 2, maximum: 50, default: 5 }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Created deep synthesis report" } }
              }
            },
            "/cluster_reports/{cluster_report_id}/summaries" => {
              get: {
                summary: "List Phase 1 per-cluster summaries",
                operationId: "listReportSummaries",
                parameters: [
                  { name: "cluster_report_id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "List of summaries" } }
              }
            },
            "/cluster_report_summaries/{id}" => {
              get: {
                summary: "Get a single cluster report summary",
                operationId: "getReportSummary",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Summary details" } }
              }
            },
            "/cluster_reports/{cluster_report_id}/sub_reports" => {
              get: {
                summary: "List Phase 2 batch sub-reports",
                operationId: "listReportSubReports",
                parameters: [
                  { name: "cluster_report_id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "List of sub-reports" } }
              }
            },
            "/cluster_sub_reports/{id}" => {
              get: {
                summary: "Get a single batch sub-report",
                operationId: "getReportSubReport",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Sub-report details" } }
              }
            },
            "/jobs" => {
              get: {
                summary: "List recent background jobs",
                operationId: "listJobs",
                parameters: [
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 20 } }
                ],
                responses: { "200" => { description: "Recent jobs" } }
              }
            },
            "/jobs/{id}" => {
              get: {
                summary: "Get status and progress of a background job",
                operationId: "getJobStatus",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "string" } }
                ],
                responses: { "200" => { description: "Job status" } }
              }
            },
            "/settings" => {
              get: {
                summary: "Get platform embedding and LLM settings",
                operationId: "getSettings",
                responses: { "200" => { description: "Settings and statistics" } }
              }
            },
            "/settings/context_window" => {
              patch: {
                summary: "Update LLM context window",
                operationId: "updateContextWindow",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[context_window],
                        properties: {
                          context_window: { type: "integer", minimum: 4096 }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Updated context window" } }
              }
            },
            "/settings/generate_embeddings" => {
              post: {
                summary: "Enqueue bulk embedding generation",
                operationId: "generateAllEmbeddings",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[model_type],
                        properties: {
                          model_type: { type: "string", enum: %w[Molecule FunctionalGroup] },
                          only_missing: { type: "boolean", default: true }
                        }
                      }
                    }
                  }
                },
                responses: { "202" => { description: "Job enqueued" } }
              }
            }
          }
        }
      end
    end
  end
end
