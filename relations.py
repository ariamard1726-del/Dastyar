import json

RELATION_PRIORITY = {
    "contradiction": 5,
    "exception": 4,
    "complement": 2,
    "related": 1
}

def get_related_materials(target_id, relationships):
    found = []
    for rel in relationships:
        if rel['source'] == target_id or rel['target'] == target_id:
            weight = RELATION_PRIORITY.get(rel['type'], 0)
            rel['weight'] = weight
            found.append(rel)
    return sorted(found, key=lambda x: x['weight'], reverse=True)

relationships = [
    {"source": "L1", "target": "L2", "type": "complement"},
    {"source": "L1", "target": "L3", "type": "exception"},
    {"source": "L1", "target": "L4", "type": "contradiction"}
]

target = "L1"
sorted_results = get_related_materials(target, relationships)

print(f"نتایج اولویت‌بندی شده برای {target}:")
for r in sorted_results:
    print(f"[{r['type'].upper()}] - اهمیت: {r['weight']} - ارجاع به: {r['target']}")
