// =====================================================================
// acordgraph — GraphRAG Sub-graph Lookup (parameterised, as-of aware)
// Parameters:
//   $party_id              : String   — resolved Party node id
//   $retrieved_clause_ids  : [String] — top-N clause ids after rerank
//   $target_peril_name     : String   — normalised RiskPeril.name / alias
//   $as_of                 : Date     — point-in-time filter (default today)
// =====================================================================
WITH coalesce($as_of, date()) AS asof

// 1) Anchor on Party → Policy → Product, honouring bitemporal edges
MATCH (p:Party {id: $party_id})-[buys:BUYS]->(pol:Policy)
WHERE buys.is_active = true
  AND buys.valid_from <= asof
  AND (buys.valid_to IS NULL OR buys.valid_to >= asof)

MATCH (pol)-[:BASED_ON]->(prod:InsuranceProduct)

// 2) Filter the candidate clauses to those that actually belong to this product
MATCH (prod)-[contains:CONTAINS]->(c:Clause)
WHERE c.id IN $retrieved_clause_ids
  AND contains.is_active = true
  AND contains.valid_from <= asof
  AND (contains.valid_to IS NULL OR contains.valid_to >= asof)

// 3) Resolve the target peril — exact name OR alias OR ICD-code hit
OPTIONAL MATCH (rp:RiskPeril)
WHERE rp.name = $target_peril_name
   OR $target_peril_name IN coalesce(rp.aliases, [])

// 4) Coverage vs Exclusion on the active clause-set
OPTIONAL MATCH (c)-[cov:COVERS]->(rp)
  WHERE cov.is_active = true
    AND cov.valid_from <= asof
    AND (cov.valid_to IS NULL OR cov.valid_to >= asof)

OPTIONAL MATCH (c)-[exc:EXCLUDES]->(rp)
  WHERE exc.is_active = true
    AND exc.valid_from <= asof
    AND (exc.valid_to IS NULL OR exc.valid_to >= asof)

RETURN
  prod.product_name        AS product,
  pol.policy_number        AS policy_number,
  c.id                     AS clause_id,
  c.title                  AS clause_title,
  c.text_content           AS clause_text,
  c.clause_type            AS clause_type,
  c.lang                   AS clause_lang,
  rp.name                  AS peril_name,
  rp.icd_code              AS peril_icd,
  cov.payout_ratio         AS payout_ratio,
  cov.waiting_period_days  AS waiting_period_days,
  CASE
    WHEN exc IS NOT NULL THEN 'EXCLUDED'
    WHEN cov IS NOT NULL THEN 'COVERED'
    ELSE 'UNDETERMINED'
  END                      AS coverage_status
ORDER BY coverage_status DESC, clause_id ASC;
