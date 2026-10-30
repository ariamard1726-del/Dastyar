import os
import json

def get_data_path():
    current_dir = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(current_dir, 'data', 'relationships.json')

def load_data():
    data_path = get_data_path()
    try:
        with open(data_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"❌ خطا: فایل در مسیر {data_path} پیدا نشد.")
        return None

def find_conflicts(article_id, data, path=None):
    """
    زنجیره تضادها را از یک ماده به صورت بازگشتی دنبال می‌کند.
    """
    if path is None:
        path = [str(article_id)]
    
    articles = data.get("articles", {})
    article = articles.get(str(article_id), {})
    next_articles = article.get("conflicts_with", [])
    
    results = []
    for next_art in next_articles:
        # محافظت در برابر حلقه (cycle)
        if str(next_art) in path:
            results.append(" -> ".join(path + [str(next_art)]) + " ⚠️ (حلقه)")
            continue
        new_path = path + [str(next_art)]
        results.append(" -> ".join(new_path))
        results.extend(find_conflicts(next_art, data, new_path))
    
    return results

if __name__ == "__main__":
    data = load_data()
    if data:
        print("✅ دیتابیس با موفقیت بارگذاری شد.")
        articles = data.get("articles", {})
        print(f"تعداد مقالات: {len(articles)}")
        print()
        
        target = "101"
        chains = find_conflicts(target, data)
        
        if chains:
            print(f"زنجیره تضادها برای ماده {target}:")
            for chain in chains:
                print(f"  {chain}")
        else:
            print(f"تضادی برای ماده {target} یافت نشد.")
