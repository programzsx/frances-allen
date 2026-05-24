#!/usr/bin/env python3
"""Frances Allen API Test Suite — post-deployment verification"""
import json, sys, urllib.request, urllib.error

BASE = "http://127.0.0.1:8000"
passed = 0
failed = 0

def req(method, path, data=None):
    url = f"{BASE}{path}"
    body = json.dumps(data).encode() if data else None
    rq = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"}, method=method)
    try:
        with urllib.request.urlopen(rq, timeout=10) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read())

def check(name, condition):
    global passed, failed
    if condition:
        print(f"  ✓ {name}")
        passed += 1
    else:
        print(f"  ✗ {name}")
        failed += 1

print("=" * 60)
print("  Frances Allen API Test Report")
print("=" * 60)

# 1. Health
print("\n[1] Health Check")
s, d = req("GET", "/")
check("status=running", d.get("status") == "running" and d.get("app") == "frances-allen")

# 2. GET categories
print("\n[2] GET /api/banks (kb_category)")
s, d = req("GET", "/api/banks?page_size=100")
total = d.get("total", 0)
print(f"  total categories: {total}")
check("categories list returned", "items" in d)

# 3. Create test category
print("\n[3] POST /api/banks (create category)")
import time
s, d = req("POST", "/api/banks", {"name": f"test_{int(time.time())}"})
cat_id = d.get("id", "")
print(f"  id={cat_id}")
check("category created", bool(cat_id))

# 4. Create QA
print("\n[4] POST /api/qas (with category_id)")
s, d = req("POST", "/api/qas", {
    "question": f"test_q_{int(time.time())}?",
    "answer": ["ok"],
    "category_id": cat_id,
    "score": 1,
    "sort_order": 10,
})
qa_id = d.get("id", "")
print(f"  id={qa_id}")
check("qa created", bool(qa_id))
check("category_id matches", d.get("category_id") == cat_id)
check("score=1", d.get("score") == 1)
check("sort_order=10", d.get("sort_order") == 10)

# 5. GET detail
print("\n[5] GET /api/qas/{id}")
s, d = req("GET", f"/api/qas/{qa_id}")
check("id present", "id" in d)
check("question present", "question" in d)
check("category_id present", "category_id" in d)
check("score present", "score" in d)
check("random_int present", "random_int" in d)
check("sort_order present", "sort_order" in d)
# Verify NO old fields
for old_field in ["bank_id", "bankId", "image_url", "imageUrl", "total", "right", "wrong"]:
    if old_field in d:
        print(f"  ✗ STALE FIELD: {old_field}")
        failed += 1

# 6. Page query + filter
print("\n[6] GET /api/qas?category_id= (filter)")
s, d = req("GET", f"/api/qas?category_id={cat_id}&page_size=10")
check("category filter works", d.get("total", 0) >= 1)

# 7. Random
print("\n[7] GET /api/qas/random/list")
s, d = req("GET", f"/api/qas/random/list?limit=5&category_id={cat_id}")
check("random returns items", isinstance(d, list))

# 8. Sequential
print("\n[8] GET /api/qas/sequential/list")
s, d = req("GET", f"/api/qas/sequential/list?limit=5&category_id={cat_id}")
check("sequential returns items", isinstance(d, list))

# 9. Wrong/weak
print("\n[9] GET /api/qas/wrong/list")
s, d = req("GET", f"/api/qas/wrong/list?limit=5&category_id={cat_id}&min_score=0")
check("wrong returns items", isinstance(d, list))

# 10. Update
print("\n[10] PUT /api/qas/{id}")
s, d = req("PUT", f"/api/qas/{qa_id}", {"score": 0, "sort_order": 20})
check("update score=0", d.get("score") == 0)
check("update sort_order=20", d.get("sort_order") == 20)

# 11. Delete QA
print("\n[11] DELETE /api/qas/{id}")
s, d = req("DELETE", f"/api/qas/{qa_id}")
check("delete qa", d.get("success") == True)

# 12. Delete category
print("\n[12] DELETE /api/banks/{id}")
s, d = req("DELETE", f"/api/banks/{cat_id}")
check("delete category", d.get("success") == True)

# Summary
print("\n" + "=" * 60)
print(f"  PASS: {passed}  FAIL: {failed}  TOTAL: {passed+failed}")
print("=" * 60)
sys.exit(0 if failed == 0 else 1)
