// =====================================================================
// acordgraph — Constraints & Indexes (Neo4j 5.13+ syntax)
// Apply with: cypher-shell -f 01_constraints_indexes.cypher
// =====================================================================

// ---------- 1. Uniqueness constraints (identity) ---------------------
CREATE CONSTRAINT party_id_unique IF NOT EXISTS
FOR (p:Party)            REQUIRE p.id IS UNIQUE;

CREATE CONSTRAINT product_id_unique IF NOT EXISTS
FOR (p:InsuranceProduct) REQUIRE p.id IS UNIQUE;

CREATE CONSTRAINT policy_id_unique IF NOT EXISTS
FOR (p:Policy)           REQUIRE p.id IS UNIQUE;

CREATE CONSTRAINT policy_num_unique IF NOT EXISTS
FOR (p:Policy)           REQUIRE p.policy_number IS UNIQUE;

CREATE CONSTRAINT clause_id_unique IF NOT EXISTS
FOR (c:Clause)           REQUIRE c.id IS UNIQUE;

CREATE CONSTRAINT subject_id_unique IF NOT EXISTS
FOR (s:Subject)          REQUIRE s.id IS UNIQUE;

CREATE CONSTRAINT peril_id_unique IF NOT EXISTS
FOR (r:RiskPeril)        REQUIRE r.id IS UNIQUE;

CREATE CONSTRAINT claim_id_unique IF NOT EXISTS
FOR (cl:Claim)           REQUIRE cl.id IS UNIQUE;

CREATE CONSTRAINT claim_num_unique IF NOT EXISTS
FOR (cl:Claim)           REQUIRE cl.claim_number IS UNIQUE;

CREATE CONSTRAINT endorsement_id_unique IF NOT EXISTS
FOR (e:Endorsement)      REQUIRE e.id IS UNIQUE;

// ---------- 2. Existence constraints (NOT NULL semantics) ------------
CREATE CONSTRAINT clause_text_not_null IF NOT EXISTS
FOR (c:Clause) REQUIRE c.text_content IS NOT NULL;

CREATE CONSTRAINT clause_type_not_null IF NOT EXISTS
FOR (c:Clause) REQUIRE c.clause_type IS NOT NULL;

// ---------- 3. Range indexes (filters in hot paths) ------------------
CREATE INDEX policy_status_idx     IF NOT EXISTS FOR (p:Policy)    ON (p.status);
CREATE INDEX policy_effective_idx  IF NOT EXISTS FOR (p:Policy)    ON (p.effective_date);
CREATE INDEX claim_date_idx        IF NOT EXISTS FOR (c:Claim)     ON (c.date_of_loss);
CREATE INDEX peril_icd_idx         IF NOT EXISTS FOR (r:RiskPeril) ON (r.icd_code);
CREATE INDEX clause_type_idx       IF NOT EXISTS FOR (c:Clause)    ON (c.clause_type);
CREATE INDEX clause_lang_idx       IF NOT EXISTS FOR (c:Clause)    ON (c.lang);

// ---------- 4. Full-text index (lexical recall + BM25 fusion) --------
CREATE FULLTEXT INDEX clause_fulltext IF NOT EXISTS
FOR (c:Clause) ON EACH [c.title, c.text_content];

CREATE FULLTEXT INDEX peril_fulltext IF NOT EXISTS
FOR (r:RiskPeril) ON EACH [r.name, r.aliases];

// ---------- 5. Vector index (semantic recall) ------------------------
// Neo4j 5.13+ uses underscore keys, not hyphen.
CREATE VECTOR INDEX clause_text_embeddings IF NOT EXISTS
FOR (c:Clause) ON (c.embedding)
OPTIONS {
  indexConfig: {
    `vector.dimensions`: 1536,
    `vector.similarity_function`: 'cosine'
  }
};
