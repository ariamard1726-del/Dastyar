import json
import os

class LegalReasoner:
    def __init__(self, db_path='relationships.json'):
        if not os.path.exists(db_path):
            print(f"❌ خطا: فایل {db_path} یافت نشد!")
            self.data = {"articles": {}}
        else:
            with open(db_path, 'r', encoding='utf-8') as f:
                self.data = json.load(f)
            print("✅ دیتابیس بارگذاری شد.")

    def find_conflict_paths(self, start_article):
        start_article = str(start_article)
        articles = self.data.get("articles", {})
        if start_article not in articles:
            return []
        
        paths = []
        queue = [(start_article, [start_article])]
        
        while queue:
            current, path = queue.pop(0)
            conflicts = articles.get(current, {}).get("conflicts_with", [])
            
            for neighbor in conflicts:
                if neighbor not in path: # جلوگیری از حلقه بی‌پایان
                    new_path = path + [neighbor]
                    paths.append(new_path)
                    queue.append((neighbor, new_path))
        return paths

if __name__ == "__main__":
    reasoner = LegalReasoner()
    article_id = "101"
    paths = reasoner.find_conflict_paths(article_id)
    
    print(f"\nگزارش تضادها برای {article_id}:")
    if not paths:
        print("تضادی یافت نشد.")
    else:
        for p in paths:
            print(" -> ".join(p))
