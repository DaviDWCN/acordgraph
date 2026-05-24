# Insurance Knowledge Graph — Technical Specification (Inbound v1.1)

> This file preserves the original technical brief verbatim for traceability.
> Authoritative requirements live in `openspec/changes/bootstrap-acord-kg/specs/`.
> Industry-best-practice deviations are documented in
> `docs/architecture-optimizations.md`.

---

# 保险知识图谱（基于 ACORD 模型）技术规范说明书
**Version:** 1.1
**Target Architecture:** Neo4j (LPG) + LLM (Hybrid GraphRAG)
**Industry Standard Alignment:** ACORD Information Model (AIM) v2.x

---

## 1. 系统架构与数据流设计 (System Architecture)

系统整体采用**双路摄入、统一语义、混合检索**的架构体系。

```
【数据源层】
 ├── A. 结构化系统 (核心/CRM系统)  ───> ETL (映射映射) ────┐
 └── B. 非结构化文档 (PDF条款/理赔单) ─> LLM 结构化抽取 ──┼─> 【存储与索引层】
                                                          │   Neo4j (LPG)
                                                          │   ├── 关系网络 (Cypher)
 【检索与服务层】                                          │   └── 向量索引 (Vector Index)
  User Query ──> [实体识别/意图解析] ──────────────────────┼─> 混合检索 (Hybrid Retrieve)
                      │                                   │
                      └─> [Cypher 生成 / 向量邻居匹配] ────┘
                                │
                                ▼
                       [子图上下文拼接] ──> [LLM生成] ──> 回答与推理路径
```

---

## 2. 本体 Schema 规范 (Ontology Schema Spec)

本规范提取 ACORD 框架中 `Party`、`Agreement`、`Subject`、`Claim` 四大支柱进行轻量级 LPG 建模，以满足生产环境下的高性能查询需求。

### 2.1 节点定义 (Nodes Definition)

| 节点标签 (Label) | 说明 | 核心属性定义 (Property: Type) | 示例 |
| :--- | :--- | :--- | :--- |
| **`Party`** | 契约或流程中的相关方 | `id: String` (Unique)<br>`name: String`<br>`type: String` (Individual / Organization)<br>`acord_code: String` | `{"id": "P_001", "name": "张三", "type": "Individual"}` |
| **`InsuranceProduct`**| 保险产品定义 | `id: String` (Unique)<br>`product_name: String`<br>`line_of_business: String` (L&A / P&C) | `{"id": "PROD_99", "product_name": "臻爱医疗险", "line_of_business": "L&A"}` |
| **`Policy`** | 保单实例（具体的保险合同） | `id: String` (Unique)<br>`policy_number: String`<br>`status: String`<br>`effective_date: Date`<br>`expiration_date: Date` | `{"id": "POL_102", "policy_number": "POL-88122", "status": "InForce"}` |
| **`Clause`** | 合同条款细则 | `id: String` (Unique)<br>`clause_type: String` (Coverage / Exclusion / Limit)<br>`title: String`<br>`text_content: String`<br>`embedding: List<Float>` (1536维向量) | `{"id": "CL_502", "clause_type": "Exclusion", "title": "既往症免责"}` |
| **`Subject`** | 承保标的（人或物） | `id: String` (Unique)<br>`subject_type: String` (Person / Vehicle / Property)<br>`description: String` | `{"id": "SUB_901", "subject_type": "Person", "description": "被保人健康状态"}` |
| **`RiskPeril`** | 承保风险或疾病 | `id: String` (Unique)<br>`name: String`<br>`icd_code: String` (若为疾病) | `{"id": "PER_401", "name": "急性心肌梗塞", "icd_code": "I21.9"}` |
| **`Claim`** | 理赔案件事件 | `id: String` (Unique)<br>`claim_number: String`<br>`date_of_loss: Date`<br>`amount_claimed: Decimal` | `{"id": "CLM_301", "claim_number": "CLM-2026-003", "amount_claimed": 50000.0}` |

### 2.2 关系与边定义 (Edges & Relationships)

| 关系类型 (Type) | 起点标签 | 终点标签 | 属性定义 (Properties) | 业务语义 |
| :--- | :--- | :--- | :--- | :--- |
| **`BUYS`** | `Party` | `Policy` | `role: String` (PolicyHolder/Insured) | 相关方购买/投保了某张保单 |
| **`BASED_ON`** | `Policy` | `InsuranceProduct` | - | 保单所关联的具体产品设计原型 |
| **`CONTAINS`** | `InsuranceProduct`| `Clause` | - | 产品条款构成 |
| **`INSURES`** | `Policy` | `Subject` | - | 保单承保的具体标的物 |
| **`COVERS`** | `Clause` | `RiskPeril` | `waiting_period_days: Int`<br>`payout_ratio: Float` | 条款所**保障**的风险/疾病及赔付比例 |
| **`EXCLUDES`** | `Clause` | `RiskPeril` | - | 条款所**免除/排除**的风险 |
| **`FILED_UNDER`** | `Claim` | `Policy` | `file_date: Date` | 客户就该理赔案件向具体保单报案 |
| **`TRIGGERED_BY`**| `Claim` | `RiskPeril` | - | 该理赔是由于特定风险/疾病引发的 |

---

## 3. 数据库约束与索引策略 (Constraints & Indexing)

详见 `assets/cypher/01_constraints_indexes.cypher`（已按 Neo4j 5.13+ 语法修订）。

## 4. 非结构化文档抽取规范 (LLM Ingestion Pipeline)

System Prompt 详见 `assets/prompts/extractor_system.md`；
JSON Schema 详见 `assets/schemas/extraction.schema.json`。

## 5. GraphRAG 混合检索及 API 规范 (GraphRAG Retrieval Spec)

参数化 Cypher 详见 `assets/cypher/10_graphrag_lookup.cypher`；
回答 Prompt 详见 `assets/prompts/answerer_system.md`。

## 6. 运维与质量保证标准 (Governance & QA)

参见 `openspec/changes/bootstrap-acord-kg/specs/governance/spec.md`。
