import json
import os


def get_data_path():
    current_dir = os.path.dirname(os.path.abspath(__file__))
    local_candidate = os.path.join(current_dir, 'data', 'relationships.json')
    if os.path.isfile(local_candidate):
        return local_candidate
    root_dir = os.path.dirname(current_dir)
    return os.path.join(root_dir, 'assets', 'relationships.json')


def load_data():
    data_path = get_data_path()
    try:
        with open(data_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except FileNotFoundError:
        print(f'❌ خطا: فایل در مسیر {data_path} پیدا نشد.')
        return None


def find_conflicts(article_id, data, path=None, max_depth=32):
    """زنجیرهٔ تضادها را از یک ماده به‌صورت بازگشتی با محافظت در برابر حلقه و عمق دنبال می‌کند."""
    if path is None:
        path = [str(article_id)]
    if len(path) > max_depth:
        return []

    articles = data.get('articles', {})
    article = articles.get(str(article_id), {})
    next_articles = article.get('conflicts_with', [])

    results = []
    for next_art in next_articles:
        next_key = str(next_art)
        if next_key in path:
            results.append(' -> '.join(path + [next_key]) + ' ⚠️ (حلقه)')
            continue
        new_path = path + [next_key]
        results.append(' -> '.join(new_path))
        if len(new_path) < max_depth:
            results.extend(find_conflicts(next_key, data, new_path, max_depth=max_depth))

    return results


if __name__ == '__main__':
    data = load_data()
    if data:
        print('✅ دیتابیس با موفقیت بارگذاری شد.')
        articles = data.get('articles', {})
        print(f'تعداد مواد دارای رابطه: {len(articles)}')
        print()

        target = '101'
        chains = find_conflicts(target, data)

        if chains:
            print(f'زنجیرهٔ تضادها برای ماده {target}:')
            for chain in chains:
                print(f'  {chain}')
        else:
            print(f'تضادی برای ماده {target} یافت نشد.')
