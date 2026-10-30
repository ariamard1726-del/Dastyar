import json
import sys
import datetime
from collections import deque


class LegalReasoner:
    def __init__(self, data_file='relationships.json'):
        with open(data_file, 'r', encoding='utf-8') as f:
            self.db = json.load(f)
        self.articles = self.db.get('articles', {})

    def exists(self, aid):
        return aid in self.articles

    def get_title(self, aid):
        return self.articles.get(aid, {}).get('title', f'ماده {aid}')

    def direct_conflicts(self, aid):
        art = self.articles.get(aid, {})
        return list(art.get('conflicts_with', []))

    def reverse_conflicts(self, aid):
        result = []
        for other_id, other in self.articles.items():
            if other_id != aid and aid in other.get('conflicts_with', []):
                result.append(other_id)
        return sorted(result, key=lambda x: (len(x), x))

    def all_direct_conflicts(self, aid):
        s = set(self.direct_conflicts(aid))
        s.update(self.reverse_conflicts(aid))
        s.discard(aid)
        return sorted(s, key=lambda x: (len(x), x))

    def conflict_chain(self, aid, max_depth=10):
        if aid not in self.articles:
            return {}
        visited = {aid: 0}
        queue = deque([(aid, 0)])
        while queue:
            current, depth = queue.popleft()
            if depth >= max_depth:
                continue
            for nxt in self.all_direct_conflicts(current):
                if nxt not in visited:
                    visited[nxt] = depth + 1
                    queue.append((nxt, depth + 1))
        visited.pop(aid, None)
        return visited

    def analyze_node(self, target_id):
        if not self.exists(target_id):
            print(f"⚠ ماده «{target_id}» در پایگاه داده وجود ندارد.")
            print(f"   مواد موجود: {', '.join(sorted(self.articles.keys()))}")
            return

        print(f"\n📌 ماده {target_id} — {self.get_title(target_id)}")
        print("-" * 55)

        direct = self.direct_conflicts(target_id)
        reverse = self.reverse_conflicts(target_id)

        if not direct and not reverse:
            print("  ✅ هیچ تضاد مستقیمی برای این ماده ثبت نشده است.")
        else:
            if direct:
                print("  ⚡ تضادهای مستقیم (این ماده →):")
                for c in direct:
                    print(f"      → {c} ({self.get_title(c)})")
            if reverse:
                print("  🔄 تضادهای معکوس (← این ماده):")
                for c in reverse:
                    print(f"      ← {c} ({self.get_title(c)})")

        chain = self.conflict_chain(target_id)
        indirect = {k: v for k, v in chain.items() if v >= 2}
        if indirect:
            print(f"  🕸 زنجیرهٔ غیرمستقیم (تا فاصله {max(indirect.values())}):")
            for cid, dist in sorted(indirect.items(), key=lambda x: (x[1], x[0])):
                print(f"      [{dist} گام] {cid} ({self.get_title(cid)})")

    def get_timestamped_report(self, target_id):
        now = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        print("=" * 55)
        print(f"  گزارش تحلیل حقوقی")
        print(f"  تاریخ:    {now}")
        print(f"  ماده:     {target_id} — {self.get_title(target_id)}")
        print(f"  کل مواد:  {len(self.articles)}")
        print("=" * 55)
        self.analyze_node(target_id)

    def show_graph(self):
        print("\n📊 نمای کلی گراف:")
        print("-" * 55)
        for aid, art in sorted(self.articles.items(), key=lambda x: (len(x[0]), x[0])):
            title = art.get('title', f'ماده {aid}')
            conflicts = art.get('conflicts_with', [])
            if conflicts:
                print(f"  {aid:<6} | {title:<14} →  {', '.join(conflicts)}")
            else:
                print(f"  {aid:<6} | {title:<14} (بدون تضاد)")

if __name__ == "__main__":
    reasoner = LegalReasoner('relationships.json')

    if len(sys.argv) > 1:
        target = sys.argv[1]
    else:
        reasoner.show_graph()
        print()
        target = input("شناسه ماده (یا Enter برای خروج): ").strip()
        if not target:
            sys.exit(0)

    reasoner.get_timestamped_report(target)
